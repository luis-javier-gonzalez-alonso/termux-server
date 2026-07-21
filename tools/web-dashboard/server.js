const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const app = express();
const port = 8080;

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// API: Get Tmux Sessions
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

// API: Kill Tmux Session
app.post('/api/sessions/kill', (req, res) => {
    const { sessionName } = req.body;
    if (!sessionName) return res.status(400).send('Session name required');
    exec(`tmux kill-session -t "${sessionName}"`, (err) => {
        if (err) return res.status(500).send('Failed to kill session');
        res.send('Success');
    });
});

// API: Get Ngrok Tunnels
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

app.listen(port, '0.0.0.0', () => {
    console.log(`Web Dashboard running at http://localhost:${port}`);
});
