#!/usr/bin/env node

/**
 * Coverage enforcement script to parse client/backend LCOV files and
 * validate coverage percentages for modified/added files against thresholds.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PROJECT_ROOT = path.resolve(__dirname, '..');

// Helper to run shell commands safely
function runCmd(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf-8', cwd: PROJECT_ROOT }).trim();
  } catch (error) {
    return '';
  }
}

// Find base branch for comparison
function getBaseBranch() {
  const currentBranch = runCmd('git rev-parse --abbrev-ref HEAD');
  if (!currentBranch || currentBranch === 'HEAD') {
    return 'main';
  }
  
  const branchesToTry = ['origin/dev', 'dev', 'origin/main', 'main'];
  for (const branch of branchesToTry) {
    if (runCmd(`git show-ref --verify --quiet refs/${branch.includes('origin') ? 'remotes/' + branch : 'heads/' + branch} && echo "OK"`)) {
      return branch;
    }
  }
  
  return 'HEAD~1';
}

// Parse LCOV file into a map of structured coverage results
function parseLcov(lcovPath, moduleRoot) {
  if (!fs.existsSync(lcovPath)) {
    console.error(`⚠️ Coverage file not found at: ${lcovPath}`);
    return null;
  }
  
  const content = fs.readFileSync(lcovPath, 'utf-8');
  const lines = content.split('\n');
  const coverageData = {};
  
  let currentFile = null;
  let linesInstrumented = 0;
  let linesHit = 0;
  const uncoveredLines = [];
  
  for (let line of lines) {
    line = line.trim();
    if (line.startsWith('SF:')) {
      let filePath = line.substring(3);
      // Resolve relative paths from the module root directory
      if (!path.isAbsolute(filePath)) {
        filePath = path.resolve(moduleRoot, filePath);
      }
      currentFile = path.relative(PROJECT_ROOT, filePath);
      linesInstrumented = 0;
      linesHit = 0;
      uncoveredLines.length = 0;
    } else if (line.startsWith('DA:')) {
      const parts = line.substring(3).split(',');
      const lineNum = parseInt(parts[0], 10);
      const hits = parseInt(parts[1], 10);
      if (hits === 0) {
        uncoveredLines.push(lineNum);
      }
    } else if (line.startsWith('LF:')) {
      linesInstrumented = parseInt(line.substring(3), 10);
    } else if (line.startsWith('LH:')) {
      linesHit = parseInt(line.substring(3), 10);
    } else if (line === 'end_of_record') {
      if (currentFile) {
        coverageData[currentFile] = {
          linesInstrumented,
          linesHit,
          coverage: linesInstrumented > 0 ? (linesHit / linesInstrumented) * 100 : 100,
          uncoveredLines: [...uncoveredLines].sort((a, b) => a - b)
        };
      }
      currentFile = null;
    }
  }
  return coverageData;
}

function main() {
  const args = process.argv.slice(2);
  const checkClient = args.includes('--client');
  const checkBackend = args.includes('--backend');
  
  if (!checkClient && !checkBackend) {
    console.error('Usage: node check-coverage-thresholds.js [--client] [--backend]');
    process.exit(1);
  }
  
  const baseBranch = getBaseBranch();
  const diffOutput = runCmd(`git diff --name-only --diff-filter=AMR ${baseBranch}`);
  if (!diffOutput) {
    console.log('✅ No modified files to check coverage for.');
    process.exit(0);
  }
  
  const changedFiles = diffOutput.split('\n').map(f => f.trim()).filter(Boolean);
  let failed = false;
  const violations = [];
  
  // 1. Client Coverage Verification
  if (checkClient) {
    console.log('📊 Verifying Client Test Coverage...');
    const clientLcovPath = path.join(PROJECT_ROOT, 'client/coverage/lcov.info');
    const clientCoverage = parseLcov(clientLcovPath, path.join(PROJECT_ROOT, 'client'));
    
    if (!clientCoverage) {
      console.error('🛑 ERROR: Client coverage report (lcov.info) is missing. Run "flutter test --coverage" first.');
      process.exit(1);
    }
    
    const clientChanged = changedFiles.filter(f => f.startsWith('client/lib/') && f.endsWith('.dart'));
    for (const file of clientChanged) {
      // Exclude generated or setup files
      if (
        file === 'client/lib/main.dart' ||
        file.includes('client/lib/core/config/firebase_options.dart') ||
        file.includes('client/lib/generated/') ||
        file.endsWith('.g.dart') ||
        file.endsWith('.freezed.dart')
      ) {
        continue;
      }
      
      const isState = file.includes('client/lib/core/state/') || 
                      file.endsWith('_notifier.dart') || 
                      file.endsWith('_cubit.dart') || 
                      file.endsWith('_bloc.dart');
      
      const isDomainOrData = file.includes('/domain/') || 
                             file.includes('/data/') || 
                             (file.startsWith('client/lib/core/') && !file.includes('/theme/') && !file.includes('/config/') && !file.includes('/constants/'));
      
      if (!isState && !isDomainOrData) {
        // Presentation/UI files that are not notifiers are warning-only or skipped here
        continue;
      }
      
      const targetThreshold = isState ? 100 : 90;
      const fileData = clientCoverage[file];
      
      if (!fileData) {
        violations.push({
          file,
          threshold: targetThreshold,
          actual: 0,
          uncovered: ['All lines (file was not executed during tests)']
        });
        failed = true;
      } else if (fileData.coverage < targetThreshold) {
        violations.push({
          file,
          threshold: targetThreshold,
          actual: fileData.coverage,
          uncovered: fileData.uncoveredLines
        });
        failed = true;
      }
    }
  }
  
  // 2. Backend Coverage Verification
  if (checkBackend) {
    console.log('📊 Verifying Backend Test Coverage...');
    const backendLcovPath = path.join(PROJECT_ROOT, 'backend/functions/coverage/lcov.info');
    const backendCoverage = parseLcov(backendLcovPath, path.join(PROJECT_ROOT, 'backend/functions'));
    
    if (!backendCoverage) {
      console.error('🛑 ERROR: Backend coverage report (lcov.info) is missing. Run "npm run test:coverage" first.');
      process.exit(1);
    }
    
    const backendChanged = changedFiles.filter(f => f.startsWith('backend/functions/src/') && f.endsWith('.ts'));
    for (const file of backendChanged) {
      if (file === 'backend/functions/src/index.ts' || file.endsWith('.d.ts')) {
        continue;
      }
      
      const targetThreshold = 90; // All backend logic files require 90%+
      const fileData = backendCoverage[file];
      
      if (!fileData) {
        violations.push({
          file,
          threshold: targetThreshold,
          actual: 0,
          uncovered: ['All lines (file was not executed during tests)']
        });
        failed = true;
      } else if (fileData.coverage < targetThreshold) {
        violations.push({
          file,
          threshold: targetThreshold,
          actual: fileData.coverage,
          uncovered: fileData.uncoveredLines
        });
        failed = true;
      }
    }
  }
  
  if (failed) {
    console.error('\n🛑 QUALITY GATE FAILURE: Test Coverage Threshold Violation!');
    console.error('Code modifications must satisfy the coverage quality standards:');
    console.error('  - Domain & Data Logic layers: 90%+ coverage');
    console.error('  - State Notifiers / ChangeNotifiers: 100% coverage\n');
    
    violations.forEach(({ file, threshold, actual, uncovered }) => {
      console.error(`  • File: ${file}`);
      console.error(`    Required: ${threshold}% | Actual: ${actual.toFixed(2)}%`);
      if (uncovered.length > 0) {
        if (typeof uncovered[0] === 'string') {
          console.error(`    Reason: ${uncovered[0]}`);
        } else {
          console.error(`    Uncovered Line Numbers: ${uncovered.slice(0, 30).join(', ')}${uncovered.length > 30 ? '... (truncated)' : ''}`);
        }
      }
      console.error('');
    });
    
    console.error('Please add tests to cover the highlighted lines.');
    process.exit(1);
  }
  
  console.log('✅ All modified files satisfy the coverage quality gate thresholds.');
  process.exit(0);
}

main();
