const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = path.resolve(__dirname, '..');

// Helper to run git commands
function runGit(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', cwd: rootDir }).trim();
  } catch (e) {
    return '';
  }
}

// Helper to get previous version of a file from Git HEAD
function getPreviousFileContent(relativeFilePath) {
  try {
    return execSync(`git show HEAD:${relativeFilePath}`, { encoding: 'utf8', cwd: rootDir, stdio: ['pipe', 'pipe', 'ignore'] });
  } catch (e) {
    return null;
  }
}

// Helper to parse semver (X.Y.Z)
function parseSemVer(versionStr) {
  const match = versionStr.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) return null;
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10)
  };
}

// Helper to increment semver patch
function bumpPatch(versionStr) {
  const parsed = parseSemVer(versionStr);
  if (!parsed) return versionStr;
  return `${parsed.major}.${parsed.minor}.${parsed.patch + 1}`;
}

// Helper to parse pubspec version (X.Y.Z+B)
function parsePubspecVersion(versionStr) {
  const match = versionStr.match(/^(\d+)\.(\d+)\.(\d+)\+(\d+)$/);
  if (!match) return null;
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
    build: parseInt(match[4], 10)
  };
}

// Helper to increment pubspec patch and build number
function bumpPubspecVersion(versionStr) {
  const parsed = parsePubspecVersion(versionStr);
  if (!parsed) return versionStr;
  return `${parsed.major}.${parsed.minor}.${parsed.patch + 1}+${parsed.build + 1}`;
}

function main() {
  console.log('🔄 Antigravity Auto-Versioning System...');

  // Get list of staged files
  const stagedOutput = runGit('git diff --cached --name-only');
  const stagedFiles = stagedOutput.split('\n').map(f => f.trim()).filter(Boolean);

  if (stagedFiles.length === 0) {
    console.log('ℹ️ No staged changes detected. Skipping version check.');
    return;
  }

  // Version files we manage
  const versionFiles = [
    'package.json',
    'VERSION',
    'client/pubspec.yaml',
    'backend/functions/package.json'
  ];

  // Filter out version files to see if actual code changes are staged
  const actualChanges = stagedFiles.filter(file => !versionFiles.includes(file));

  if (actualChanges.length === 0) {
    console.log('ℹ️ Only versioning files are staged. Skipping auto-bump.');
    return;
  }

  let clientChanged = false;
  let backendChanged = false;

  for (const file of actualChanges) {
    if (file.startsWith('client/')) {
      clientChanged = true;
    } else if (file.startsWith('backend/')) {
      backendChanged = true;
    }
  }

  let newGlobalVersion = null;

  // 1. Root package.json
  const rootPackageJsonPath = path.join(rootDir, 'package.json');
  if (fs.existsSync(rootPackageJsonPath)) {
    const prevContent = getPreviousFileContent('package.json');
    const currentContent = fs.readFileSync(rootPackageJsonPath, 'utf8');
    const currentJson = JSON.parse(currentContent);
    const currentVersion = currentJson.version || '1.0.0';

    let prevVersion = '1.0.0';
    if (prevContent) {
      try {
        prevVersion = JSON.parse(prevContent).version || '1.0.0';
      } catch (e) {}
    }

    if (currentVersion === prevVersion) {
      // Auto-bump root version
      const bumped = bumpPatch(currentVersion);
      currentJson.version = bumped;
      fs.writeFileSync(rootPackageJsonPath, JSON.stringify(currentJson, null, 2) + '\n', 'utf8');
      runGit('git add package.json');
      console.log(`📈 Auto-bumped root package.json: ${prevVersion} -> ${bumped}`);
      newGlobalVersion = bumped;
    } else {
      console.log(`✨ Manual bump detected in root package.json: ${currentVersion}`);
      newGlobalVersion = currentVersion;
    }
  }

  // 2. VERSION file
  if (newGlobalVersion) {
    const versionFilePath = path.join(rootDir, 'VERSION');
    fs.writeFileSync(versionFilePath, newGlobalVersion + '\n', 'utf8');
    runGit('git add VERSION');
    console.log(`📝 Updated VERSION file: ${newGlobalVersion}`);
  }

  // 3. Client pubspec.yaml
  if (clientChanged) {
    const pubspecPath = path.join(rootDir, 'client', 'pubspec.yaml');
    if (fs.existsSync(pubspecPath)) {
      const prevContent = getPreviousFileContent('client/pubspec.yaml');
      const currentContent = fs.readFileSync(pubspecPath, 'utf8');

      const versionRegex = /^version:\s*(.+)$/m;
      const currentMatch = currentContent.match(versionRegex);
      const currentVersion = currentMatch ? currentMatch[1].trim() : '1.0.0+1';

      let prevVersion = '1.0.0+1';
      if (prevContent) {
        const prevMatch = prevContent.match(versionRegex);
        if (prevMatch) {
          prevVersion = prevMatch[1].trim();
        }
      }

      if (currentVersion === prevVersion) {
        const bumped = bumpPubspecVersion(currentVersion);
        const updatedContent = currentContent.replace(versionRegex, `version: ${bumped}`);
        fs.writeFileSync(pubspecPath, updatedContent, 'utf8');
        runGit('git add client/pubspec.yaml');
        console.log(`📈 Auto-bumped client/pubspec.yaml: ${prevVersion} -> ${bumped}`);
      } else {
        console.log(`✨ Manual bump detected in client/pubspec.yaml: ${currentVersion}`);
      }
    }
  }

  // 4. Backend package.json
  if (backendChanged) {
    const backendPackageJsonPath = path.join(rootDir, 'backend', 'functions', 'package.json');
    if (fs.existsSync(backendPackageJsonPath)) {
      const prevContent = getPreviousFileContent('backend/functions/package.json');
      const currentContent = fs.readFileSync(backendPackageJsonPath, 'utf8');
      const currentJson = JSON.parse(currentContent);
      const currentVersion = currentJson.version || '1.0.0';

      let prevVersion = '1.0.0';
      if (prevContent) {
        try {
          prevVersion = JSON.parse(prevContent).version || '1.0.0';
        } catch (e) {}
      }

      if (currentVersion === prevVersion) {
        const bumped = bumpPatch(currentVersion);
        currentJson.version = bumped;
        fs.writeFileSync(backendPackageJsonPath, JSON.stringify(currentJson, null, 2) + '\n', 'utf8');
        runGit('git add backend/functions/package.json');
        console.log(`📈 Auto-bumped backend functions package.json: ${prevVersion} -> ${bumped}`);
      } else {
        console.log(`✨ Manual bump detected in backend functions package.json: ${currentVersion}`);
      }
    }
  }

  console.log('✅ Auto-versioning complete!');
}

main();
