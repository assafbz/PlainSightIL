const { spawn } = require('child_process');
const path = require('path');

// Ensure Homebrew openjdk is in path for Mac users
if (process.platform === 'darwin') {
  process.env.PATH = `/opt/homebrew/opt/openjdk/bin:${process.env.PATH}`;
}

const rootDir = path.resolve(__dirname, '..');

// 1. Build backend functions
console.log('📦 Building backend functions...');
const buildProc = spawn('npm', ['run', 'build'], {
  cwd: path.join(rootDir, 'backend', 'functions'),
  stdio: 'inherit',
  shell: true
});

buildProc.on('close', (code) => {
  if (code !== 0) {
    console.error(`❌ Backend build failed with code ${code}. Aborting startup.`);
    process.exit(code);
  }

  console.log('✅ Backend build successful. Starting services...');
  startServices();
});

function startServices() {
  const children = [];

  // Start Firebase Emulators
  console.log('🔥 Starting Firebase Emulators (Firestore & Functions)...');
  const backendProc = spawn('npx', ['firebase-tools', 'emulators:start', '--project', 'demo-plainsightil'], {
    cwd: path.join(rootDir, 'backend'),
    shell: true,
    detached: true
  });
  children.push(backendProc);

  // Start Flutter Client
  const device = process.env.FLUTTER_DEVICE || 'chrome';
  const port = process.env.FLUTTER_PORT || '8080';
  console.log(`📱 Starting Flutter Client on device: ${device} (port: ${port})...`);
  
  const clientArgs = ['run', '-d', device];
  if (device === 'chrome') {
    clientArgs.push('--web-port', port);
  }
  
  const clientProc = spawn('flutter', clientArgs, {
    cwd: path.join(rootDir, 'client'),
    shell: true,
    detached: true
  });
  children.push(clientProc);

  // Automatic database seeding once emulators are ready
  let seeded = false;
  function triggerSeeding() {
    if (seeded) return;
    seeded = true;
    console.log('🌱 Firebase Emulators ready. Triggering database seeding...');
    
    const http = require('http');
    const syncEndpoints = [
      '/demo-plainsightil/us-central1/manualSyncMetadata',
      '/demo-plainsightil/us-central1/manualSyncPermitApps',
      '/demo-plainsightil/us-central1/manualSyncAntennas',
      '/demo-plainsightil/us-central1/manualSyncCompaniesLiquidation'
    ];

    const runSync = (index) => {
      if (index >= syncEndpoints.length) {
        console.log('✅ Local database seeding complete!');
        return;
      }
      const path = syncEndpoints[index];
      console.log(`🌱 Seeding: requesting ${path}...`);
      
      const req = http.get({
        hostname: 'localhost',
        port: 5002,
        path: path,
        timeout: 60000 // 60s timeout
      }, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
          console.log(`🌱 Seed response for ${path}: Code ${res.statusCode}`);
          runSync(index + 1);
        });
      });

      req.on('error', (err) => {
        console.error(`❌ Seeding failed for ${path}: ${err.message}`);
        runSync(index + 1);
      });
    };

    // Wait a couple of seconds to ensure functions emulator is fully serving
    setTimeout(() => {
      runSync(0);
    }, 2000);
  }

  // Handle prefixing helper
  function prefixStream(stream, prefix, colorCode) {
    let buffer = '';
    stream.on('data', (data) => {
      buffer += data.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop(); // keep last incomplete line
      for (const line of lines) {
        if (line.trim()) {
          console.log(`\x1b[${colorCode}m[${prefix}]\x1b[0m ${line}`);
          if (prefix === 'Backend' && line.includes('All emulators ready!')) {
            triggerSeeding();
          }
        }
      }
    });
  }

  // Prefix output streams: 33 = yellow (backend), 36 = cyan (client)
  prefixStream(backendProc.stdout, 'Backend', '33');
  prefixStream(backendProc.stderr, 'Backend-Err', '31');
  prefixStream(clientProc.stdout, 'Client', '36');
  prefixStream(clientProc.stderr, 'Client-Err', '31');

  // Handle termination signals
  const cleanExit = () => {
    console.log('\n🛑 Shutting down all processes...');
    for (const child of children) {
      if (child.pid) {
        try {
          if (process.platform === 'win32') {
            spawn('taskkill', ['/pid', child.pid, '/f', '/t']);
          } else {
            process.kill(-child.pid, 'SIGINT'); // Kill process group
          }
        } catch (e) {
          try {
            child.kill('SIGINT');
          } catch (err) {
            // ignore
          }
        }
      }
    }
    // Give child processes a moment to shut down, then exit
    setTimeout(() => {
      process.exit();
    }, 1000);
  };

  process.on('SIGINT', cleanExit);
  process.on('SIGTERM', cleanExit);
}
