const { execSync } = require('child_process');

const offset = parseInt(process.env.PORT_OFFSET, 10) || 0;
console.log(`🔍 Locating and terminating PlainSightIL processes (offset: ${offset})...`);

const ports = [
  process.env.FIRESTORE_PORT ? parseInt(process.env.FIRESTORE_PORT, 10) : (8081 + offset),
  process.env.AUTH_PORT ? parseInt(process.env.AUTH_PORT, 10) : (9099 + offset),
  process.env.PUBSUB_PORT ? parseInt(process.env.PUBSUB_PORT, 10) : (8085 + offset),
  process.env.FUNCTIONS_PORT ? parseInt(process.env.FUNCTIONS_PORT, 10) : (5002 + offset),
  process.env.EMULATOR_UI_PORT ? parseInt(process.env.EMULATOR_UI_PORT, 10) : (4001 + offset),
  process.env.CLIENT_PORT ? parseInt(process.env.CLIENT_PORT, 10) : (8080 + offset)
];
const pids = new Set();

for (const port of ports) {
  try {
    const output = execSync(`lsof -t -i :${port}`).toString().trim();
    if (output) {
      output.split('\n').forEach(pid => {
        if (pid) pids.add(parseInt(pid, 10));
      });
    }
  } catch (e) {
    // Port not in use, ignore
  }
}

if (pids.size === 0) {
  console.log('✅ No processes found running on ports ' + ports.join(', ') + '.');
  process.exit(0);
}

console.log(`Killing processes with PIDs: ${Array.from(pids).join(', ')}`);
for (const pid of pids) {
  try {
    process.kill(pid, 'SIGKILL');
    console.log(`  - Killed PID ${pid}`);
  } catch (e) {
    console.error(`  - Failed to kill PID ${pid}: ${e.message}`);
  }
}

console.log('✅ All project processes terminated.');
