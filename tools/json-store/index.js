const express = require('express');
const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');

const app = express();
app.use(express.json({ limit: '10mb' }));

// Parse arguments
let port = 3000;
let folderPath = './data';

const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--port' && args[i + 1]) {
    port = parseInt(args[i + 1], 10);
    i++;
  } else if (args[i] === '--folder' && args[i + 1]) {
    folderPath = args[i + 1];
    i++;
  }
}

folderPath = path.resolve(folderPath);
if (!fs.existsSync(folderPath)) {
  fs.mkdirSync(folderPath, { recursive: true });
}

// Helper to get safe file path
const getFilePath = (reqPath) => {
  if (reqPath === '/' || reqPath === '') {
    throw new Error('Path cannot be root');
  }
  
  // Remove leading slash for normalization
  let normalizedPath = reqPath;
  if (normalizedPath.startsWith('/')) {
    normalizedPath = normalizedPath.slice(1);
  }
  
  normalizedPath = path.normalize(normalizedPath);
  
  // Prevent directory traversal
  if (normalizedPath.startsWith('..') || path.isAbsolute(normalizedPath)) {
    throw new Error('Invalid path');
  }

  const safePath = path.join(folderPath, normalizedPath);
  
  // Double check it's within the folder
  if (!safePath.startsWith(folderPath)) {
    throw new Error('Invalid path');
  }
  
  return safePath.endsWith('.json') ? safePath : safePath + '.json';
};

// Helper to get schema
const getSchema = () => {
  const schemaPath = path.join(folderPath, 'schema.json');
  if (fs.existsSync(schemaPath)) {
    try {
      const content = fs.readFileSync(schemaPath, 'utf8');
      return JSON.parse(content);
    } catch (err) {
      console.error('Error reading schema.json:', err);
      return null;
    }
  }
  return null;
};

// GET / - List all objects
app.get('/', (req, res) => {
  const walkSync = (dir, filelist = []) => {
    try {
      const files = fs.readdirSync(dir);
      for (const file of files) {
        const dirFile = path.join(dir, file);
        if (fs.statSync(dirFile).isDirectory()) {
          filelist = walkSync(dirFile, filelist);
        } else {
          filelist.push(dirFile);
        }
      }
    } catch (err) {
      // Ignore read errors
    }
    return filelist;
  };

  try {
    const allFiles = walkSync(folderPath);
    const objects = allFiles
      .filter(f => f.endsWith('.json') && f !== path.join(folderPath, 'schema.json'))
      .map(f => {
        let p = path.relative(folderPath, f);
        if (p.endsWith('.json')) p = p.slice(0, -5);
        // Replace windows backslashes with forward slashes for the API
        return p.split(path.sep).join('/');
      });
    res.json({ objects });
  } catch (err) {
    res.status(500).json({ error: 'Failed to list objects' });
  }
});

// GET /* - Get an object
app.get('/*', (req, res) => {
  try {
    const filePath = getFilePath(req.path);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'Object not found' });
    }
    const content = fs.readFileSync(filePath, 'utf8');
    res.json(JSON.parse(content));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// PUT or POST /* - Create or update an object
const handleWrite = (req, res) => {
  try {
    if (req.path === '/' || req.path === '') {
      return res.status(400).json({ error: 'Path cannot be root. Specify an object name (e.g. /my-item).' });
    }

    let isSchemaFile = (req.path === '/schema' || req.path === '/schema.json');
    let targetPath = req.path;
    if (isSchemaFile) {
        targetPath = 'schema.json'; // Force exact name
    }

    const filePath = getFilePath(targetPath);

    // Validate if schema exists and we aren't uploading the schema itself
    if (!isSchemaFile) {
      const schema = getSchema();
      if (schema) {
        const ajv = new Ajv();
        const validate = ajv.compile(schema);
        const valid = validate(req.body);
        if (!valid) {
          return res.status(400).json({ error: 'Schema validation failed', details: validate.errors });
        }
      }
    }

    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(filePath, JSON.stringify(req.body, null, 2));
    
    // Return the clean path without .json extension
    let returnedPath = path.relative(folderPath, filePath).split(path.sep).join('/');
    if (returnedPath.endsWith('.json')) {
        returnedPath = returnedPath.slice(0, -5);
    }
    res.json({ success: true, key: returnedPath });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

app.put('/*', handleWrite);
app.post('/*', handleWrite);

// DELETE /* - Delete an object
app.delete('/*', (req, res) => {
  try {
    if (req.path === '/' || req.path === '') {
      return res.status(400).json({ error: 'Path cannot be root.' });
    }
    
    let targetPath = req.path;
    if (targetPath === '/schema') targetPath = 'schema.json';

    const filePath = getFilePath(targetPath);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Object not found' });
    }
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.listen(port, () => {
  console.log(`JSON Object Store running on port ${port}`);
  console.log(`Serving folder: ${folderPath}`);
});
