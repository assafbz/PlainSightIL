const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Ensure Homebrew openjdk is in path for Mac users if run locally
if (process.platform === 'darwin') {
  process.env.PATH = `/opt/homebrew/opt/openjdk/bin:${process.env.PATH}`;
}

const rootDir = path.resolve(__dirname, '..');

// Calculate dynamic ports based on PORT_OFFSET or custom env
const offset = parseInt(process.env.PORT_OFFSET, 10) || 0;
const ports = {
  client: (parseInt(process.env.CLIENT_PORT, 10) || 8080) + offset,
  firestore: (parseInt(process.env.FIRESTORE_PORT, 10) || 8081) + offset,
  auth: (parseInt(process.env.AUTH_PORT, 10) || 9099) + offset,
  functions: (parseInt(process.env.FUNCTIONS_PORT, 10) || 5002) + offset,
  ui: (parseInt(process.env.EMULATOR_UI_PORT, 10) || 4001) + offset,
};

// Generate dynamic Firebase config file
console.log('⚙️ [CI-E2E] Generating dynamic Firebase emulator configuration...');
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
} catch (e) {
  console.error('❌ [CI-E2E] Failed to write temporary configuration:', e.message);
  process.exit(1);
}

console.log(`🚀 [CI-E2E] Starting Firebase Emulators (Firestore: ${ports.firestore}, Auth: ${ports.auth}, Functions: ${ports.functions})...`);
const emulatorsProc = spawn('npx', ['firebase-tools', 'emulators:start', '--project', 'demo-plainsightil', '--config', 'firebase.tmp.json', '--only', 'firestore,auth,functions'], {
  cwd: path.join(rootDir, 'backend'),
  shell: true,
  detached: false
});


let serveProc = null;
let playwrightProc = null;
let cleanupCalled = false;

// Helper to kill processes safely
function cleanup(exitCode = 0) {
  if (cleanupCalled) return;
  cleanupCalled = true;
  console.log('\n🧹 [CI-E2E] Cleaning up background processes...');
  
  if (serveProc) {
    console.log('🧹 [CI-E2E] Terminating HTTP serve server...');
    try { serveProc.kill('SIGKILL'); } catch(e) {}
  }
  if (emulatorsProc) {
    console.log('🧹 [CI-E2E] Terminating Firebase Emulators...');
    try { emulatorsProc.kill('SIGKILL'); } catch(e) {}
  }
  
  // Delete temporary Firebase configuration file
  try {
    if (fs.existsSync(tempConfigPath)) {
      fs.unlinkSync(tempConfigPath);
      console.log('🗑️ [CI-E2E] Temporary config file cleaned.');
    }
  } catch (e) {
    console.warn('⚠️ [CI-E2E] Failed to delete temporary Firebase config:', e.message);
  }

  // Run global process kill script to make absolutely sure ports are free
  console.log('🧹 [CI-E2E] Running final port sweep...');
  const killProc = spawn('node', [path.join(rootDir, 'scripts', 'kill.js')], {
    env: {
      ...process.env,
      CLIENT_PORT: ports.client,
      FIRESTORE_PORT: ports.firestore,
      AUTH_PORT: ports.auth,
      FUNCTIONS_PORT: ports.functions,
      EMULATOR_UI_PORT: ports.ui
    },
    stdio: 'inherit',
    shell: true
  });
  killProc.on('close', () => {
    process.exit(exitCode);
  });

}

// Watch emulators output
let buffer = '';
emulatorsProc.stdout.on('data', (data) => {
  const text = data.toString();
  process.stdout.write(`\x1b[33m[Emulators]\x1b[0m ${text}`);
  buffer += text;
  
  // Trigger seeding when emulators are ready
  if (buffer.includes('All emulators ready!')) {
    buffer = ''; // clear buffer to prevent multiple triggers
    triggerSeeding();
  }
});

emulatorsProc.stderr.on('data', (data) => {
  process.stderr.write(`\x1b[31m[Emulators-Err]\x1b[0m ${data.toString()}`);
});

emulatorsProc.on('close', (code) => {
  console.log(`🔥 [CI-E2E] Emulators process closed with code ${code}`);
  if (code !== 0 && code !== null) {
    cleanup(code);
  }
});

function triggerSeeding() {
  console.log('🌱 [CI-E2E] Emulators ready. Seeding local database collections...');
  const http = require('http');
  const syncEndpoints = [
    '/demo-plainsightil/us-central1/manualSyncMetadata',
    '/demo-plainsightil/us-central1/manualSyncPermitApps',
    '/demo-plainsightil/us-central1/manualSyncAntennas',
    '/demo-plainsightil/us-central1/manualSyncCompaniesLiquidation'
  ];

  const runSync = (index) => {
    if (index >= syncEndpoints.length) {
      console.log('✅ [CI-E2E] Local database seeding complete! Starting static client server...');
      startServer();
      return;
    }
    const path = syncEndpoints[index];
    console.log(`🌱 [CI-E2E] Seeding endpoint: ${path}`);
    
    const req = http.get({
      hostname: 'localhost',
      port: ports.functions,
      path: path,
      timeout: 60000
    }, (res) => {

      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        console.log(`🌱 [CI-E2E] Seeded ${path}: Code ${res.statusCode}`);
        runSync(index + 1);
      });
    });

    req.on('error', (err) => {
      console.error(`❌ [CI-E2E] Seeding failed for ${path}: ${err.message}`);
      // Retry once or proceed to not block the CI run completely
      setTimeout(() => runSync(index + 1), 1000);
    });
  };

  // Wait a moment for functions environment configurations to mount
  setTimeout(() => {
    runSync(0);
  }, 3000);
}

function startServer() {
  console.log(`🌐 [CI-E2E] Starting static HTTP server for Flutter Web build on port ${ports.client}...`);
  serveProc = spawn('npx', ['serve', 'client/build/web', '-l', ports.client.toString(), '-s'], {
    cwd: rootDir,
    shell: true
  });

  serveProc.stdout.on('data', (data) => {
    const text = data.toString();
    process.stdout.write(`\x1b[36m[Serve]\x1b[0m ${text}`);
    if (text.includes('Accepting connections') || text.includes('Accepting connections')) {
      runPlaywright();
    }
  });

  serveProc.stderr.on('data', (data) => {
    process.stderr.write(`\x1b[31m[Serve-Err]\x1b[0m ${data.toString()}`);
  });
  
  serveProc.on('close', (code) => {
    console.log(`🌐 [CI-E2E] Serve process closed with code ${code}`);
    if (code !== 0 && code !== null) {
      cleanup(code);
    }
  });
}

function runPlaywright() {
  console.log('🧪 [CI-E2E] Running Playwright E2E Tests...');
  playwrightProc = spawn('npx', ['playwright', 'test'], {
    cwd: rootDir,
    env: {
      ...process.env,
      CLIENT_PORT: ports.client.toString(),
      FIRESTORE_PORT: ports.firestore.toString(),
      AUTH_PORT: ports.auth.toString(),
      FUNCTIONS_PORT: ports.functions.toString()
    },
    stdio: 'inherit',
    shell: true
  });


  playwrightProc.on('close', (code) => {
    console.log(`🧪 [CI-E2E] Playwright tests execution completed with code ${code}`);
    cleanup(code);
  });
}

// Register termination listeners
process.on('SIGINT', () => cleanup(130));
process.on('SIGTERM', () => cleanup(143));
