const express = require('express');
const { exec, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const app = express();
const port = 8080;

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

const STATE_DIR = path.join(process.env.HOME, '.termux-server');
const APPS_DIR = path.join(STATE_DIR, 'apps');
const STARTUP_FILE = path.join(STATE_DIR, 'startup.list');

// Ensure state dirs
if (!fs.existsSync(APPS_DIR)) fs.mkdirSync(APPS_DIR, { recursive: true });

// --- Existing Endpoints ---

app.get('/api/sessions', (req, res) => {
    exec('tmux ls -F "#{session_name}|#{session_created}|#{window_active}"', (err, stdout) => {
        if (err) return res.json([]);
        const sessions = stdout.trim().split('\n').filter(Boolean).map(line => {
            const [name, created, active] = line.split('|');
            return { name, created, active };
        });
        res.json(sessions);
    });
});

app.post('/api/sessions/kill', (req, res) => {
    const { sessionName, removeAutostart } = req.body;
    if (!sessionName) return res.status(400).send('Session name required');
    
    if (removeAutostart && fs.existsSync(STARTUP_FILE)) {
        try {
            const lines = fs.readFileSync(STARTUP_FILE, 'utf8').split('\n').filter(l => l && !l.startsWith(sessionName + '|'));
            fs.writeFileSync(STARTUP_FILE, lines.join('\n') + '\n');
        } catch(e) {
            console.error('Failed to update startup file:', e);
        }
    }

    exec(`tmux kill-session -t "${sessionName}"`, (err) => {
        if (err) return res.status(500).send('Failed to kill session');
        res.send('Success');
    });
});

app.get('/api/sessions/:name/log', (req, res) => {
    const { name } = req.params;
    exec(`tmux capture-pane -t "${name}" -p -S -100`, (err, stdout) => {
        if (err) return res.status(500).send('Log not available or session dead.\n');
        res.send(stdout);
    });
});

app.get('/api/ngrok', (req, res) => {
    exec('curl -s http://127.0.0.1:4040/api/tunnels', (err, stdout) => {
        if (err) return res.json({ tunnels: [] });
        try {
            res.json(JSON.parse(stdout));
        } catch(e) {
            res.json({ tunnels: [] });
        }
    });
});

// --- New Management Endpoints ---

// Configure Ngrok Token
app.post('/api/ngrok/token', (req, res) => {
    const { token } = req.body;
    if (!token) return res.status(400).send('Token required');
    exec(`proot-distro login alpine --isolated -- ngrok config add-authtoken "${token}"`, (err, stdout, stderr) => {
        if (err) return res.status(500).send(stderr || err.message);
        res.send('Authtoken added successfully');
    });
});

// Add Ngrok Service
app.post('/api/ngrok/service', (req, res) => {
    const { name, servicePort } = req.body; 
    if (!name || !servicePort) return res.status(400).send('Name and port required');
    
    const cmd = `
        proot-distro login alpine --isolated -- /bin/sh -c "
            echo '  ${name}:' >> /root/.config/ngrok/ngrok.yml
            echo '    proto: http' >> /root/.config/ngrok/ngrok.yml
            echo '    addr: ${servicePort}' >> /root/.config/ngrok/ngrok.yml
        "
    `;
    exec(cmd, (err, stdout, stderr) => {
        if (err) return res.status(500).send(stderr || err.message);
        
        // Restart ngrok session
        exec('tmux kill-session -t "ngrok-system"', () => {
            exec(`tmux new-session -d -s "ngrok-system" "proot-distro login alpine --isolated -- ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout; echo ''; echo '--- Ngrok Exited ---'; read r"`, (err2) => {
                if (err2) return res.status(500).send('Failed to restart Ngrok');
                res.send('Service added and Ngrok restarted');
            });
        });
    });
});

// Start JSON Store
app.post('/api/json-store/start', (req, res) => {
    const { storePort, folder, expose } = req.body; 
    if (!storePort || !folder) return res.status(400).send('Port and folder required');
    
    const startStore = () => {
        const cmd = `tmux new-session -d -s "json-store-${storePort}" "proot-distro login alpine --isolated -- /bin/sh -c 'mkdir -p \\"${folder}\\" && cd \\"${folder}\\" && node \\"/usr/local/share/termux-server/tools/json-store/index.js\\" --port \\"${storePort}\\" --folder \\"${folder}\\"'; echo ''; echo '--- Process Exited ---'; read r"`;
        exec(cmd, (err, stdout, stderr) => {
            if (err) return res.status(500).send(stderr || err.message);
            res.send('JSON Store started');
        });
    };

    if (expose) {
        const ngrokCmd = `
            proot-distro login alpine --isolated -- /bin/sh -c "
                if ! grep -q 'addr: ${storePort}' /root/.config/ngrok/ngrok.yml 2>/dev/null; then
                    echo '  json-store-${storePort}:' >> /root/.config/ngrok/ngrok.yml
                    echo '    proto: http' >> /root/.config/ngrok/ngrok.yml
                    echo '    addr: ${storePort}' >> /root/.config/ngrok/ngrok.yml
                fi
            "
        `;
        exec(ngrokCmd, (err) => {
            if (err) return res.status(500).send('Failed to configure Ngrok');
            exec('tmux kill-session -t "ngrok-system"', () => {
                exec(`tmux new-session -d -s "ngrok-system" "proot-distro login alpine --isolated -- ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout; echo ''; echo '--- Ngrok Exited ---'; read r"`, (err2) => {
                    startStore();
                });
            });
        });
    } else {
        startStore();
    }
});

// Start Custom Script
app.post('/api/scripts/start', (req, res) => {
    const { name, command, autostart, dir } = req.body;
    if (!name || !command) return res.status(400).send('Name and command required');
    
    const workDir = dir || process.env.HOME;
    
    if (autostart) {
        let lines = [];
        if (fs.existsSync(STARTUP_FILE)) {
            lines = fs.readFileSync(STARTUP_FILE, 'utf8').split('\n').filter(l => l && !l.startsWith(name + '|'));
        }
        lines.push(`${name}|${workDir}|${command}`);
        fs.writeFileSync(STARTUP_FILE, lines.join('\n') + '\n');
    }
    
    const sName = name.replace(/\s+/g, '');
    const cmd = `tmux new-session -d -c "${workDir}" -s "${sName}" "proot-distro login alpine --isolated -- /bin/sh -c 'cd \\"$1\\" && eval \\"$2\\"' _ \\"${workDir}\\" \\"${command}\\"; echo ''; echo '--- Process Exited ---'; read r"`;
    
    exec(cmd, (err, stdout, stderr) => {
        if (err) return res.status(500).send(stderr || err.message);
        res.send('Script started');
    });
});

// Deploy App via streaming POST
app.post('/api/apps/deploy', (req, res) => {
    const { url, name, startCmd, autostart } = req.body;
    if (!url) return res.status(400).send('URL required');
    
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Transfer-Encoding', 'chunked');
    
    const sendLog = (msg) => res.write(`${msg}\n`);
    const sendDone = (success, msg) => {
        res.write(`\n--- DONE: ${success ? 'SUCCESS' : 'FAILED'} ---\n${msg}\n`);
        res.end();
    };

    const repoName = path.basename(url, '.git');
    const appDir = path.join(APPS_DIR, repoName);
    
    sendLog(`Starting deployment of ${url}...`);
    
    if (fs.existsSync(appDir)) {
        sendLog(`Directory ${repoName} exists. Removing...`);
        try {
            fs.rmSync(appDir, { recursive: true, force: true });
        } catch(e) {
            return sendDone(false, `Failed to remove old directory: ${e.message}`);
        }
    }
    
    sendLog(`Cloning repository in Alpine...`);
    const cloneCmd = `git clone "${url}" "${appDir}"`;
    const gitProc = spawn('proot-distro', ['login', 'alpine', '--isolated', '--', '/bin/sh', '-c', cloneCmd]);
    
    gitProc.on('error', (err) => {
        sendDone(false, `Git spawn error: ${err.message}`);
    });
    
    gitProc.stdout.on('data', d => res.write(d));
    gitProc.stderr.on('data', d => res.write(d));
    
    gitProc.on('close', code => {
        if (code !== 0) return sendDone(false, 'Git clone failed.');
        
        sendLog(`\nRepository cloned successfully to ${appDir}.`);
        
        let installCmd = '';
        if (fs.existsSync(path.join(appDir, 'package.json'))) {
            sendLog('Found package.json. Will install Node.js dependencies...');
            installCmd = `cd "${appDir}" && npm install --no-audit --no-fund --silent`;
        } else if (fs.existsSync(path.join(appDir, 'requirements.txt'))) {
            sendLog('Found requirements.txt. Will install Python dependencies...');
            installCmd = `cd "${appDir}" && pip install -r requirements.txt --break-system-packages`;
        } else {
            sendLog('No auto-detectable dependencies found.');
        }
        
        const finishDeployment = () => {
            const sName = name ? name.replace(/\s+/g, '') : repoName;
            if (autostart) {
                try {
                    let lines = [];
                    if (fs.existsSync(STARTUP_FILE)) {
                        lines = fs.readFileSync(STARTUP_FILE, 'utf8').split('\n').filter(l => l && !l.startsWith(sName + '|'));
                    }
                    lines.push(`${sName}|${appDir}|${startCmd || ''}`);
                    fs.writeFileSync(STARTUP_FILE, lines.join('\n') + '\n');
                    sendLog('Added to startup list.');
                } catch(e) {
                    sendLog(`Warning: Failed to write to startup file: ${e.message}`);
                }
            }
            
            if (startCmd) {
                sendLog(`Starting app session '${sName}'...`);
                const tCmd = `tmux new-session -d -c "${appDir}" -s "${sName}" "proot-distro login alpine --isolated -- /bin/sh -c 'cd \\"$1\\" && eval \\"$2\\"' _ \\"${appDir}\\" \\"${startCmd}\\"; echo ''; echo '--- Process Exited ---'; read r"`;
                exec(tCmd, (e, stdo, stde) => {
                    if (e) return sendDone(false, `Failed to start tmux session: ${stde || e.message}`);
                    sendDone(true, 'Deployment complete and app started successfully!');
                });
            } else {
                sendDone(true, 'Deployment complete! (No start command provided)');
            }
        };
        
        if (installCmd) {
            sendLog(`\nRunning dependency installation in Alpine... (this may take a while)`);
            const installer = spawn('proot-distro', ['login', 'alpine', '--isolated', '--', '/bin/sh', '-c', installCmd]);
            
            installer.on('error', (err) => {
                sendLog(`\nWarning: Failed to spawn dependency installer: ${err.message}`);
                finishDeployment();
            });

            installer.stdout.on('data', d => res.write(d));
            installer.stderr.on('data', d => res.write(d));
            installer.on('close', icode => {
                if (icode !== 0) sendLog(`\nWarning: Dependency installation exited with code ${icode}`);
                else sendLog('\nDependencies installed successfully.');
                finishDeployment();
            });
        } else {
            finishDeployment();
        }
    });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Web Dashboard running at http://localhost:${port}`);
});
