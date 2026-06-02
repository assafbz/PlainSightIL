const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Ensure Homebrew openjdk is in path for Mac users
if (process.platform === 'darwin') {
  process.env.PATH = `/opt/homebrew/opt/openjdk/bin:${process.env.PATH}`;
}

const rootDir = path.resolve(__dirname, '..');

// Read port offset and compute dynamic ports
const offset = parseInt(process.env.PORT_OFFSET, 10) || 0;
const ports = {
  client: (parseInt(process.env.CLIENT_PORT, 10) || 8080) + offset,
  firestore: (parseInt(process.env.FIRESTORE_PORT, 10) || 8081) + offset,
  auth: (parseInt(process.env.AUTH_PORT, 10) || 9099) + offset,
  functions: (parseInt(process.env.FUNCTIONS_PORT, 10) || 5002) + offset,
  ui: (parseInt(process.env.EMULATOR_UI_PORT, 10) || 4001) + offset,
};

// 0. Pre-flight check: Terminate lingering processes on the selected ports to prevent locks
console.log(`🧹 Running pre-flight port clean-up (offset: ${offset})...`);
try {
  execSync(`CLIENT_PORT=${ports.client} FIRESTORE_PORT=${ports.firestore} AUTH_PORT=${ports.auth} FUNCTIONS_PORT=${ports.functions} EMULATOR_UI_PORT=${ports.ui} node scripts/kill.js`, {
    stdio: 'inherit',
    cwd: rootDir
  });
} catch (e) {
  console.warn('⚠️ Port cleanup encountered an error (ignoring):', e.message);
}

// Generate temporary Firebase emulator config containing dynamic ports
console.log('⚙️ Generating dynamic Firebase emulator configuration...');
const baseConfigPath = path.join(rootDir, 'backend', 'firebase.json');
const tempConfigPath = path.join(rootDir, 'backend', 'firebase.tmp.json');
try {
  const baseConfig = JSON.parse(fs.readFileSync(baseConfigPath, 'utf8'));
  baseConfig.emulators = {
    firestore: { port: ports.firestore, host: '127.0.0.1' },
    auth: { port: ports.auth, host: '127.0.0.1' },
    functions: { port: ports.functions, host: '127.0.0.1' },
    ui: { enabled: true, port: ports.ui, host: '127.0.0.1' }
  };
  fs.writeFileSync(tempConfigPath, JSON.stringify(baseConfig, null, 2));
  console.log(`✅ Temporary Firebase config written to backend/firebase.tmp.json`);
} catch (e) {
  console.error('❌ Failed to write temporary Firebase config:', e.message);
  process.exit(1);
}


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

  // Start Firebase Emulators using the generated temp config file
  console.log(`🔥 Starting Firebase Emulators (Firestore on ${ports.firestore}, Auth on ${ports.auth}, Functions on ${ports.functions})...`);
  const backendProc = spawn('npx', ['firebase-tools', 'emulators:start', '--project', 'demo-plainsightil', '--config', 'firebase.tmp.json'], {
    cwd: path.join(rootDir, 'backend'),
    shell: true,
    detached: true
  });
  children.push(backendProc);

  // Start Flutter Client
  const device = process.env.FLUTTER_DEVICE || 'chrome';
  
  if (device !== 'none') {
    console.log(`📱 Starting Flutter Client on device: ${device} (port: ${ports.client})...`);
    
    let gitBranch = 'unknown';
    try {
      gitBranch = execSync('git rev-parse --abbrev-ref HEAD').toString().trim();
    } catch (_) {}
    
    const clientArgs = ['run', '-d', device];
    if (device === 'chrome') {
      clientArgs.push('--web-port', ports.client.toString());
    }
    
    // Inject dynamic emulator port targets and Git branch context
    clientArgs.push(
      '--dart-define', `FIRESTORE_PORT=${ports.firestore}`,
      '--dart-define', `AUTH_PORT=${ports.auth}`,
      '--dart-define', `FUNCTIONS_PORT=${ports.functions}`,
      '--dart-define', `GIT_BRANCH=${gitBranch}`
    );
    
    const clientProc = spawn('flutter', clientArgs, {
      cwd: path.join(rootDir, 'client'),
      shell: true,
      detached: true
    });
    children.push(clientProc);
    prefixStream(clientProc.stdout, 'Client', '36');
    prefixStream(clientProc.stderr, 'Client-Err', '31');
  } else {
    console.log('📱 Skipping Flutter Client startup (FLUTTER_DEVICE is set to none).');
  }


  // Automatic database seeding once emulators are ready
  let seeded = false;
  function triggerSeeding() {
    if (seeded) return;
    seeded = true;
    console.log('🌱 Firebase Emulators ready. Triggering database seeding...');
    
    const http = require('http');
    const syncEndpoints = [
      '/demo-plainsightil/us-central1/manualSyncMetadata',
      '/demo-plainsightil/us-central1/manualSyncDoctorsLicenses',
      '/demo-plainsightil/us-central1/manualSyncPermitApps',
      '/demo-plainsightil/us-central1/manualSyncAntennas',
      '/demo-plainsightil/us-central1/manualSyncCompaniesLiquidation',
      '/demo-plainsightil/us-central1/manualApiHealthCheck'
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
        port: ports.functions,
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
    
    // Clean up temporary config file
    try {
      if (fs.existsSync(tempConfigPath)) {
        fs.unlinkSync(tempConfigPath);
        console.log('🗑️ Cleaned up temporary Firebase configuration.');
      }
    } catch (e) {
      console.warn('⚠️ Failed to delete temporary Firebase config:', e.message);
    }
    
    // Give child processes a moment to shut down, then exit
    setTimeout(() => {
      process.exit();
    }, 1000);
  };


  process.on('SIGINT', cleanExit);
  process.on('SIGTERM', cleanExit);
}
