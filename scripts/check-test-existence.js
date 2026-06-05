#!/usr/bin/env node

/**
 * Static validation script to enforce that every new or modified logic-bearing source file 
 * in the client and backend has a corresponding test file.
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
  
  // Try comparing against common target branches
  const branchesToTry = ['origin/dev', 'dev', 'origin/main', 'main'];
  for (const branch of branchesToTry) {
    if (runCmd(`git show-ref --verify --quiet refs/${branch.includes('origin') ? 'remotes/' + branch : 'heads/' + branch} && echo "OK"`)) {
      return branch;
    }
  }
  
  return 'HEAD~1';
}

function checkExistence() {
  const baseBranch = getBaseBranch();
  console.log(`🔍 Comparing changes against base branch: ${baseBranch}`);
  
  // Get list of added or modified files (excluding deletions)
  const diffOutput = runCmd(`git diff --name-only --diff-filter=AMR ${baseBranch}`);
  if (!diffOutput) {
    console.log('✅ No modified files detected.');
    process.exit(0);
  }
  
  const changedFiles = diffOutput.split('\n').map(f => f.trim()).filter(Boolean);
  let failed = false;
  const missingTests = [];
  
  for (const file of changedFiles) {
    const filename = path.basename(file);
    
    // 1. Check Client (Flutter) Files
    if (file.startsWith('client/lib/')) {
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
      
      // Enforce ONLY for logic-bearing layers: domain, data, and state management
      const isState = file.includes('client/lib/core/state/') || 
                      file.endsWith('_notifier.dart') || 
                      file.endsWith('_cubit.dart') || 
                      file.endsWith('_bloc.dart');
      
      const isDomainOrData = file.includes('/domain/') || 
                             file.includes('/data/') || 
                             (file.startsWith('client/lib/core/') && !file.includes('/theme/') && !file.includes('/config/'));
      
      if (!isState && !isDomainOrData) {
        // UI widgets and page layouts are verified via integration/E2E and don't require 1-to-1 unit tests
        continue;
      }
      
      const relativePath = file.substring('client/lib/'.length);
      const testPath = `client/test/${relativePath.replace(/\.dart$/, '_test.dart')}`;
      
      if (!fs.existsSync(path.join(PROJECT_ROOT, testPath))) {
        missingTests.push({ source: file, expectedTest: testPath });
        failed = true;
      }
    }
    
    // 2. Check Backend (Firebase Functions) Files
    if (file.startsWith('backend/functions/src/')) {
      // Exclude main index and type files
      if (
        file === 'backend/functions/src/index.ts' ||
        file.endsWith('.d.ts')
      ) {
        continue;
      }
      
      const relativePath = file.substring('backend/functions/src/'.length);
      
      // Backend test structure supports both structured subfolders and legacy flat tests structure
      const structuredTestPath = `backend/functions/test/${relativePath.replace(/\.ts$/, '.test.ts')}`;
      const flatTestPath = `backend/functions/test/${filename.replace(/\.ts$/, '.test.ts')}`;
      
      const existsStructured = fs.existsSync(path.join(PROJECT_ROOT, structuredTestPath));
      const existsFlat = fs.existsSync(path.join(PROJECT_ROOT, flatTestPath));
      
      if (!existsStructured && !existsFlat) {
        missingTests.push({ source: file, expectedTest: structuredTestPath });
        failed = true;
      }
    }
  }
  
  if (failed) {
    console.error('\n🛑 QUALITY GATE FAILURE: Missing Test Files!');
    console.error('The PlainSightIL testing pyramid requires test coverage for all modified logic.');
    console.error('Please create the following test files before committing/pushing:\n');
    
    missingTests.forEach(({ source, expectedTest }) => {
      console.error(`  • Source: ${source}`);
      console.error(`    ↳ Expected Test: ${expectedTest}\n`);
    });
    
    process.exit(1);
  }
  
  console.log('✅ All modified source files have corresponding test files.');
  process.exit(0);
}

checkExistence();
