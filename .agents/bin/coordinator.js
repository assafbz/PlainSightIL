#!/usr/bin/env node

/**
 * Antigravity Multi-Agent SDLC Coordinator
 * Pure Node.js CLI to parse filesystem state, execute transitions, and simulate loops.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const STATE_DIR = path.join(ROOT_DIR, 'state', 'active_issues');
const CONFIG_FILE = path.join(ROOT_DIR, 'AGENTS.md');

// Utility: Ensure directory exists
function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

// Simple Frontmatter Parser (Pure JS, no external dependency)
function parseMarkdownState(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const parts = content.split('---');
  if (parts.length < 3) {
    return { metadata: {}, body: content };
  }
  const yamlText = parts[1];
  const body = parts.slice(2).join('---');
  const metadata = {};
  
  yamlText.split('\n').forEach(line => {
    const cleanLine = line.trim();
    if (!cleanLine || cleanLine.startsWith('#')) return;
    const colonIndex = cleanLine.indexOf(':');
    if (colonIndex > 0) {
      const key = cleanLine.substring(0, colonIndex).trim();
      let value = cleanLine.substring(colonIndex + 1).trim();
      
      // Strip quotes
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      
      // Parse basic types
      if (value.toLowerCase() === 'true') value = true;
      else if (value.toLowerCase() === 'false') value = false;
      else if (!isNaN(value) && value !== '') value = Number(value);
      
      metadata[key] = value;
    }
  });
  
  return { metadata, body };
}

// Simple YAML / Frontmatter Serializer
function serializeMarkdownState(metadata, body) {
  let yamlText = '---\n';
  for (const [key, val] of Object.entries(metadata)) {
    if (typeof val === 'string' && (val.includes(' ') || val.includes(':'))) {
      yamlText += `${key}: "${val}"\n`;
    } else {
      yamlText += `${key}: ${val}\n`;
    }
  }
  yamlText += '---';
  return yamlText + body;
}

// Simple parser to extract lifecycle_paths YAML block from AGENTS.md
function parseAgentsConfig() {
  if (!fs.existsSync(CONFIG_FILE)) {
    throw new Error(`Config file not found at ${CONFIG_FILE}`);
  }
  const content = fs.readFileSync(CONFIG_FILE, 'utf8');
  const yamlMatch = content.match(/lifecycle_paths:\s*\n([\s\S]*?)(?=\n\n\w|\n#|\n---|\n```)/);
  if (!yamlMatch) {
    throw new Error("Could not find lifecycle_paths in AGENTS.md");
  }
  
  const yamlLines = yamlMatch[1].split('\n');
  const workflows = {};
  let currentType = null;
  let currentPhase = null;
  
  yamlLines.forEach(line => {
    const cleanLine = line.trim();
    if (!cleanLine || cleanLine.startsWith('#')) return;
    
    const typeMatch = line.match(/^  ([a-zA-Z0-9_-]+):\s*$/);
    if (typeMatch) {
      currentType = typeMatch[1];
      workflows[currentType] = [];
      currentPhase = null;
      return;
    }
    
    const idMatch = cleanLine.match(/^-\s*id:\s*["']?([a-zA-Z0-9_-]+)["']?/);
    if (idMatch) {
      currentPhase = { id: idMatch[1] };
      if (currentType && workflows[currentType]) {
        workflows[currentType].push(currentPhase);
      }
      return;
    }
    
    if (currentPhase) {
      const colonIndex = cleanLine.indexOf(':');
      if (colonIndex > 0) {
        const key = cleanLine.substring(0, colonIndex).trim();
        let value = cleanLine.substring(colonIndex + 1).split('#')[0].trim();
        
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        
        if (value === 'true') value = true;
        else if (value === 'false') value = false;
        
        currentPhase[key] = value;
      }
    }
  });
  
  return workflows;
}

// Simple parser to extract personas YAML block from AGENTS.md
function parsePersonasConfig() {
  if (!fs.existsSync(CONFIG_FILE)) {
    return {};
  }
  const content = fs.readFileSync(CONFIG_FILE, 'utf8');
  const yamlMatch = content.match(/personas:\s*\n([\s\S]*?)(?=\n\n\w|\n#|\n---|\n```)/);
  if (!yamlMatch) {
    return {};
  }
  
  const yamlLines = yamlMatch[1].split('\n');
  const personas = {};
  let currentPersona = null;
  
  yamlLines.forEach(line => {
    const cleanLine = line.trim();
    if (!cleanLine || cleanLine.startsWith('#')) return;
    
    const personaMatch = line.match(/^  ([a-zA-Z0-9_-]+):\s*$/);
    if (personaMatch) {
      currentPersona = personaMatch[1];
      personas[currentPersona] = {};
      return;
    }
    
    if (currentPersona) {
      const colonIndex = cleanLine.indexOf(':');
      if (colonIndex > 0) {
        const key = cleanLine.substring(0, colonIndex).trim();
        let value = cleanLine.substring(colonIndex + 1).split('#')[0].trim();
        
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        
        personas[currentPersona][key] = value;
      }
    }
  });
  
  return personas;
}

// Get the issue life cycle path from AGENTS.md
function getWorkflowPhases(issueType) {
  try {
    const workflows = parseAgentsConfig();
    const personas = parsePersonasConfig();
    
    const parsedPhases = workflows[issueType];
    if (parsedPhases && parsedPhases.length > 0) {
      return parsedPhases.map(phase => {
        const persona = personas[phase.assignee];
        return {
          id: phase.id,
          assignee: phase.assignee,
          label: (persona && persona.git_label) || (phase.id === 'triage' ? `type:${issueType}` : 'status:blocked'),
          hitl_gate: phase.hitl_gate === true
        };
      });
    }
  } catch (e) {
    console.warn("⚠️ Warning: Failed to parse AGENTS.md dynamically, falling back to static defaults.", e.message);
  }

  // Simple fallback structure mapping the approved workflow phases in AGENTS.md
  const defaultPhases = {
    feature: [
      { id: 'triage', assignee: 'coordinator', label: 'type:feature' },
      { id: 'discovery', assignee: 'product_manager', label: 'status:discovery' },
      { id: 'ui_ux_design', assignee: 'ui_ux_designer', label: 'status:ui-ux-design' },
      { id: 'architecture_design', assignee: 'system_architect', label: 'status:tech-design' },
      { id: 'security_audit', assignee: 'security_engineer', label: 'status:security-audit' },
      { id: 'blueprinting', assignee: 'tech_lead', label: 'status:blueprint' },
      { id: 'implementation', assignee: 'senior_developer', label: 'status:development' },
      { id: 'qa_validation', assignee: 'qa_engineer', label: 'status:qa-validation' },
      { id: 'lessons_learned', assignee: 'lessons_learned', label: 'status:lessons-learned' },
      { id: 'merge_approval', assignee: 'coordinator', label: 'status:blocked' }
    ],
    bug: [
      { id: 'triage', assignee: 'coordinator', label: 'type:bug' },
      { id: 'qa_reproduction', assignee: 'qa_engineer', label: 'status:qa-validation' },
      { id: 'blueprinting', assignee: 'tech_lead', label: 'status:blueprint' },
      { id: 'implementation', assignee: 'senior_developer', label: 'status:development' },
      { id: 'qa_validation', assignee: 'qa_engineer', label: 'status:qa-validation' },
      { id: 'lessons_learned', assignee: 'lessons_learned', label: 'status:lessons-learned' },
      { id: 'merge_approval', assignee: 'coordinator', label: 'status:blocked' }
    ],
    refactor: [
      { id: 'triage', assignee: 'coordinator', label: 'type:refactor' },
      { id: 'architecture_design', assignee: 'system_architect', label: 'status:tech-design' },
      { id: 'blueprinting', assignee: 'tech_lead', label: 'status:blueprint' },
      { id: 'implementation', assignee: 'senior_developer', label: 'status:development' },
      { id: 'qa_validation', assignee: 'qa_engineer', label: 'status:qa-validation' },
      { id: 'lessons_learned', assignee: 'lessons_learned', label: 'status:lessons-learned' },
      { id: 'merge_approval', assignee: 'coordinator', label: 'status:blocked' }
    ]
  };

  return defaultPhases[issueType] || defaultPhases['feature'];
}

// Print Status of Active Issues
function printStatus() {
  if (!fs.existsSync(STATE_DIR)) {
    console.log('No active issues directory found.');
    return;
  }
  const files = fs.readdirSync(STATE_DIR).filter(f => f.endsWith('.md'));
  if (files.length === 0) {
    console.log('No active issue files.');
    return;
  }

  console.log('\n=== ACTIVE SDLC ISSUES ===');
  files.forEach(file => {
    const filePath = path.join(STATE_DIR, file);
    try {
      const { metadata } = parseMarkdownState(filePath);
      console.log(`\nIssue ID:   #${metadata.issue_id || 'UNKNOWN'}`);
      console.log(`Title:      ${metadata.title || 'Untitled'}`);
      console.log(`Type:       ${metadata.type || 'unknown'}`);
      console.log(`Phase:      ${metadata.current_phase || 'unknown'}`);
      console.log(`Assignee:   ${metadata.assigned_agent || 'unassigned'}`);
      console.log(`Status:     ${metadata.status || 'unknown'}`);
      console.log(`HITL Block: ${metadata.hitl_approval_required ? 'YES 🛑' : 'NO ✅'}`);
      console.log(`State File: .agents/state/active_issues/${file}`);
    } catch (e) {
      console.error(`Error parsing ${file}:`, e.message);
    }
  });
  console.log('===========================\n');
}

// Get list of changed files relative to base branch
function getChangedFiles() {
  try {
    const baseBranch = execSync('git show-ref --verify --quiet refs/heads/dev && echo dev || echo main', { encoding: 'utf8' }).trim();
    const diffCommand = `git diff --name-only origin/${baseBranch} 2>/dev/null || git diff --name-only ${baseBranch} 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null`;
    const files = execSync(diffCommand, { encoding: 'utf8' }).split('\n').map(f => f.trim()).filter(Boolean);
    return files;
  } catch (e) {
    return [];
  }
}

// Utility: run a shell validation command in cwd and capture output
function runCheck(command, cwd, description) {
  console.log(`⏳ Running ${description}... (${command})`);
  try {
    const output = execSync(command, { cwd, stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });
    console.log(`✅ ${description} passed.`);
    return { success: true, logs: output };
  } catch (error) {
    console.error(`❌ ${description} FAILED!`);
    const stdout = error.stdout ? error.stdout.toString() : '';
    const stderr = error.stderr ? error.stderr.toString() : '';
    const logs = stdout + '\n' + stderr;
    console.error(logs); // Ensure logs are output to console for visual feedback
    return { success: false, logs: logs };
  }
}

// Utility: check if a deliverable exists and is non-empty
function verifyDeliverable(issueId, filename) {
  const deliverablePath = path.join(ROOT_DIR, 'state', `issue_${issueId}`, filename);
  if (!fs.existsSync(deliverablePath)) {
    const errMsg = `🛑 QUALITY GATE FAILURE: Missing required deliverable '${filename}'!\nExpected file: .agents/state/issue_${issueId}/${filename}`;
    console.error(errMsg);
    return { success: false, failureLogs: errMsg };
  }
  const stats = fs.statSync(deliverablePath);
  if (stats.size < 50) {
    const errMsg = `🛑 QUALITY GATE FAILURE: Deliverable '${filename}' appears empty or is just a placeholder.\nFile path: .agents/state/issue_${issueId}/${filename}`;
    console.error(errMsg);
    return { success: false, failureLogs: errMsg };
  }
  return { success: true, failureLogs: '' };
}

// Validate Quality Gates for the transitioning phase
function validateQualityGate(issueId, currentPhase) {
  if (process.env.SKIP_SDLC === '1' || process.env.SKIP_SDLC === 'true') {
    console.log('⚠️  Bypassing Quality Gates checks (SKIP_SDLC=1). Note: Skipping SDLC requires HITL approval.');
    return { success: true, failureLogs: '' };
  }

  console.log(`🛡️  Enforcing Quality Gates for transition from '${currentPhase}'...`);
  let result;

  switch (currentPhase) {
    case 'discovery':
      return verifyDeliverable(issueId, 'PRD.md');
      
    case 'ui_ux_design':
      return verifyDeliverable(issueId, 'DESIGN.md');
      
    case 'architecture_design':
      return verifyDeliverable(issueId, 'TDD.md');
      
    case 'security_audit':
      return verifyDeliverable(issueId, 'SECURITY.md');
      
    case 'blueprinting':
      return verifyDeliverable(issueId, 'BLUEPRINT.md');
      
    case 'implementation':
      const changedFiles = getChangedFiles();
      const hasClientChanges = changedFiles.some(f => f.startsWith('client/'));
      const hasBackendChanges = changedFiles.some(f => f.startsWith('backend/'));
      const repoRoot = path.resolve(ROOT_DIR, '..');

      // If no files detected (e.g. running outside git or initial commit), run all as fallback
      const runAll = !hasClientChanges && !hasBackendChanges;

      if (hasClientChanges || runAll) {
        const clientDir = path.join(repoRoot, 'client');
        result = runCheck('dart format --set-exit-if-changed .', clientDir, 'Client formatting check');
        if (!result.success) return { success: false, failureLogs: result.logs };
        result = runCheck('flutter analyze', clientDir, 'Client static analysis');
        if (!result.success) return { success: false, failureLogs: result.logs };
        result = runCheck('flutter test', clientDir, 'Client unit tests');
        if (!result.success) return { success: false, failureLogs: result.logs };
      }

      if (hasBackendChanges || runAll) {
        const backendDir = path.join(repoRoot, 'backend', 'functions');
        // Ensure node_modules exists
        if (!fs.existsSync(path.join(backendDir, 'node_modules'))) {
          result = runCheck('npm ci || npm install', backendDir, 'Backend dependency installation');
          if (!result.success) return { success: false, failureLogs: result.logs };
        }
        result = runCheck('npm run format:check', backendDir, 'Backend formatting check');
        if (!result.success) return { success: false, failureLogs: result.logs };
        result = runCheck('npm run lint', backendDir, 'Backend linting');
        if (!result.success) return { success: false, failureLogs: result.logs };
        result = runCheck('npm run test', backendDir, 'Backend unit tests');
        if (!result.success) return { success: false, failureLogs: result.logs };
        result = runCheck('npm run build', backendDir, 'Backend TypeScript compilation');
        if (!result.success) return { success: false, failureLogs: result.logs };
      }
      return { success: true, failureLogs: '' };
      
    case 'qa_validation':
      return verifyDeliverable(issueId, 'QA_REPORT.md');
      
    case 'lessons_learned':
      return verifyDeliverable(issueId, 'LESSONS_LEARNED.md');
      
    default:
      return { success: true, failureLogs: '' };
  }
}

// --- GITHUB INTEGRATION HELPERS ---

const PHASE_KEYWORDS = {
  discovery: ['Executive Summary', 'Open Questions', 'Obstacles'],
  ui_ux_design: ['Visual Theme', 'Constraints & Hurdles'],
  architecture_design: ['Architectural Summary', 'Performance & Security', 'Implementation Decisions'],
  security_audit: ['Threat Modeling', 'Audit Findings', 'Security Hurdles'],
  blueprinting: ['Blueprinting Observations'],
  qa_validation: ['Test Summary', 'Discovered Defects', 'QA Hurdles'],
  lessons_learned: ['Executive Summary', 'Pitfalls', 'Future Cycles']
};

function getDeliverableFilename(phase) {
  const mapping = {
    discovery: 'PRD.md',
    ui_ux_design: 'DESIGN.md',
    architecture_design: 'TDD.md',
    security_audit: 'SECURITY.md',
    blueprinting: 'BLUEPRINT.md',
    qa_validation: 'QA_REPORT.md',
    lessons_learned: 'LESSONS_LEARNED.md'
  };
  return mapping[phase];
}

function parseSections(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const content = fs.readFileSync(filePath, 'utf8');
  const sections = {};
  let currentHeader = '';
  let currentLines = [];

  content.split('\n').forEach(line => {
    const headerMatch = line.match(/^(#{1,6})\s+(.*)$/);
    if (headerMatch) {
      if (currentHeader) {
        sections[currentHeader] = currentLines.join('\n').trim();
      }
      currentHeader = headerMatch[2].trim();
      currentLines = [];
    } else {
      if (currentHeader) {
        currentLines.push(line);
      }
    }
  });
  if (currentHeader) {
    sections[currentHeader] = currentLines.join('\n').trim();
  }
  return sections;
}

function extractFindings(phase, issueId) {
  const filename = getDeliverableFilename(phase);
  if (!filename) {
    if (phase === 'implementation') {
      return `- All automated checks passed successfully (Client formatting, Flutter analysis, Unit tests, and TypeScript compilation).\n- Code changes have been verified locally.`;
    }
    return '';
  }

  const filePath = path.join(ROOT_DIR, 'state', `issue_${issueId}`, filename);
  if (!fs.existsSync(filePath)) {
    return `*No deliverable file found at .agents/state/issue_${issueId}/${filename}*`;
  }

  try {
    const sections = parseSections(filePath);
    const keywords = PHASE_KEYWORDS[phase] || [];
    const extracted = [];

    for (const [header, content] of Object.entries(sections)) {
      const match = keywords.some(keyword => header.toLowerCase().includes(keyword.toLowerCase()));
      if (match) {
        extracted.push(`##### ${header}\n\n${content}`);
      }
    }

    if (extracted.length === 0) {
      // Fallback: If no headers matched, return first 1000 characters
      const content = fs.readFileSync(filePath, 'utf8');
      return `*Could not match specific sections. Summary of deliverable:*\n\n${content.substring(0, 1000)}${content.length > 1000 ? '...' : ''}`;
    }

    return extracted.join('\n\n');
  } catch (e) {
    return `*Error reading/parsing findings: ${e.message}*`;
  }
}

function runGitHubCommand(command) {
  try {
    execSync(command, { stdio: 'pipe' });
    return true;
  } catch (e) {
    console.warn(`⚠️ Warning: GitHub command failed: ${command}\nError: ${e.message}`);
    return false;
  }
}

function ensureLabelExists(labelName) {
  const createCmd = `gh label create "${labelName}" --color "ededed" --force`;
  runGitHubCommand(createCmd);
}

function updateGitHubIssue(issueId, prevLabel, newLabel, commentBody) {
  if (process.env.SKIP_GITHUB === '1' || process.env.SKIP_GITHUB === 'true') {
    console.log('⚠️ Skipping GitHub integration (SKIP_GITHUB=1)');
    return;
  }

  console.log(`🔄 Syncing with GitHub Issue #${issueId}...`);

  // 1. Update labels
  let labelFlags = '';
  if (prevLabel) {
    ensureLabelExists(prevLabel);
    labelFlags += ` --remove-label "${prevLabel}"`;
  }
  if (newLabel) {
    ensureLabelExists(newLabel);
    labelFlags += ` --add-label "${newLabel}"`;
  }

  if (labelFlags) {
    const editCmd = `gh issue edit ${issueId}${labelFlags}`;
    runGitHubCommand(editCmd);
  }

  // 2. Post comment
  if (commentBody) {
    const tempDir = path.join(ROOT_DIR, 'state', `issue_${issueId}`);
    ensureDir(tempDir);
    const tempCommentPath = path.join(tempDir, '.temp_github_comment.md');
    fs.writeFileSync(tempCommentPath, commentBody, 'utf8');

    const commentCmd = `gh issue comment ${issueId} --body-file "${tempCommentPath}"`;
    const success = runGitHubCommand(commentCmd);

    try {
      fs.unlinkSync(tempCommentPath);
    } catch (e) {}

    if (success) {
      console.log(`✅ Posted SDLC progress comment to GitHub Issue #${issueId}`);
    }
  }
}

// Transition Issue to next phase
function transitionIssue(issueIdStr, comment = '') {
  const issueId = Number(issueIdStr);
  const fileName = `issue_${issueId}.md`;
  const filePath = path.join(STATE_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.error(`Error: Issue file not found at ${filePath}`);
    process.exit(1);
  }

  const { metadata, body } = parseMarkdownState(filePath);
  const type = metadata.type || 'feature';
  const phases = getWorkflowPhases(type);
  const currentPhaseIndex = phases.findIndex(p => p.id === metadata.current_phase);

  if (currentPhaseIndex === -1) {
    console.error(`Error: Unknown phase '${metadata.current_phase}' in issue schema.`);
    process.exit(1);
  }

  // Check HITL gate block
  if (metadata.hitl_approval_required && !metadata.hitl_approved_by) {
    console.log(`🛑 Cannot transition Issue #${issueId}: Blocked on Human-in-the-Loop review!`);
    console.log(`Please add 'hitl_approved_by: "your_username"' to the frontmatter first.`);
    return;
  }

  // Validate programmatic quality gates
  const gateResult = validateQualityGate(issueId, metadata.current_phase);
  if (!gateResult.success) {
    console.log(`🛑 Transition blocked due to Quality Gate violation.`);
    
    const activePhase = metadata.current_phase;
    const targetAgent = metadata.assigned_agent || 'senior_developer';
    
    // Write QUALITY_GATE_FAILURE.md under state/issue_<id>/
    const issueDir = path.join(ROOT_DIR, 'state', `issue_${issueId}`);
    ensureDir(issueDir);
    const failureFilePath = path.join(issueDir, 'QUALITY_GATE_FAILURE.md');
    const timestampStr = new Date().toISOString().replace('T', ' ').substring(0, 19);
    
    const failureContent = `# Quality Gate Failure: Issue #${issueId}\n\n- **Timestamp**: ${timestampStr}\n- **Phase**: \`${activePhase}\`\n- **Assignee**: \`${targetAgent}\`\n\n## 📋 Error & Verification Diagnostics\n\n\`\`\`text\n${gateResult.failureLogs}\n\`\`\`\n`;
    fs.writeFileSync(failureFilePath, failureContent, 'utf8');
    
    // Auto reject the issue state back to implementation
    metadata.current_phase = 'implementation';
    metadata.assigned_agent = 'senior_developer';
    metadata.status = 'blueprint-revision';
    metadata.hitl_approval_required = false;
    metadata.hitl_approved_by = '';
    
    // Append audit log
    const logEntry = `\n- **${timestampStr}**: ❌ Quality Gate verification FAILED during \`${activePhase}\`. Sent back to \`senior_developer\` for blueprint-revision.`;
    let updatedBody = body;
    const auditHeader = '## 📋 Audit Log & Stage Transitions';
    const auditLogIdx = body.indexOf(auditHeader);
    if (auditLogIdx !== -1) {
      updatedBody = body.substring(0, auditLogIdx + auditHeader.length) + logEntry + body.substring(auditLogIdx + auditHeader.length);
    }
    
    // Update blockers section
    const blockerHeader = '## 🔄 Blockers & Review Feedback';
    const blockerIdx = updatedBody.indexOf(blockerHeader);
    const loopEntry = `\n### Quality Gate Failure Loop (${timestampStr})\n- **By**: Automated Orchestrator\n- **Feedback**: Verification check failed in phase \`${activePhase}\`. Diagnostics saved to [QUALITY_GATE_FAILURE.md](file://${failureFilePath}).\n- **Status**: Active Revision Needed\n`;
    if (blockerIdx !== -1) {
      updatedBody = updatedBody.substring(0, blockerIdx + blockerHeader.length) + loopEntry + updatedBody.substring(blockerIdx + blockerHeader.length);
    } else {
      updatedBody += `\n\n${blockerHeader}${loopEntry}`;
    }
    
    const serialized = serializeMarkdownState(metadata, updatedBody);
    fs.writeFileSync(filePath, serialized, 'utf8');
    
    console.log(`❌ Auto-rejected Issue #${issueId} due to verification failures. Re-assigned to senior_developer.`);

    // --- GITHUB SYNC ON QUALITY GATE FAILURE ---
    const prevPhaseInfo = phases.find(p => p.id === activePhase);
    const prevLabel = prevPhaseInfo ? prevPhaseInfo.label : null;
    const devLabelInfo = phases.find(p => p.id === 'implementation');
    const devLabel = devLabelInfo ? devLabelInfo.label : 'status:development';

    let commentBody = `### ❌ Quality Gate Verification FAILED in \`${activePhase}\`\n`;
    commentBody += `- **Status**: \`blueprint-revision\`\n`;
    commentBody += `- **Assignee**: \`senior_developer\`\n\n`;
    commentBody += `#### 📋 Diagnostics & Failure Logs:\n\n\`\`\`text\n${gateResult.failureLogs}\n\`\`\`\n`;

    updateGitHubIssue(issueId, prevLabel, devLabel, commentBody);
    
    return;
  }

  // If the phase was implementation, and we successfully validated it:
  if (metadata.current_phase === 'implementation') {
    try {
      const headHash = execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();
      const verifiedFilePath = path.join(ROOT_DIR, 'state', `issue_${issueId}`, '.sdlc_verified');
      fs.writeFileSync(verifiedFilePath, headHash, 'utf8');
      console.log(`✅ Generated .sdlc_verified token for commit: ${headHash}`);
    } catch (e) {
      console.warn('Warning: Could not write .sdlc_verified token:', e.message);
    }
  }

  if (currentPhaseIndex >= phases.length - 1) {
    console.log(`✅ Issue #${issueId} is already in the final phase: ${metadata.current_phase}.`);
    return;
  }

  const nextPhase = phases[currentPhaseIndex + 1];
  
  // Apply update
  const prevPhaseId = metadata.current_phase;
  const prevPhaseInfo = phases.find(p => p.id === prevPhaseId);
  const prevLabel = prevPhaseInfo ? prevPhaseInfo.label : null;

  metadata.current_phase = nextPhase.id;
  metadata.assigned_agent = nextPhase.assignee;
  metadata.status = 'in-progress';
  
  // Reset approval tags for next phase gates
  if (nextPhase.id === 'architecture_design' || nextPhase.id === 'merge_approval' || nextPhase.id === 'security_audit' || nextPhase.id === 'ui_ux_design') {
    metadata.hitl_approval_required = true;
    metadata.hitl_approved_by = '';
  } else {
    metadata.hitl_approval_required = false;
    metadata.hitl_approved_by = '';
  }

  // Update audit log
  const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
  let logEntry = `\n- **${timestamp}**: Transitioned from \`${prevPhaseId}\` to \`${nextPhase.id}\`. Assigned to \`${nextPhase.assignee}\`.`;
  if (comment) {
    logEntry += ` Notes: ${comment}`;
  }

  // Find the Audit Log header in the markdown body and insert the log
  let updatedBody = body;
  const auditHeader = '## 📋 Audit Log & Stage Transitions';
  const headerIdx = body.indexOf(auditHeader);
  if (headerIdx !== -1) {
    const insertIdx = headerIdx + auditHeader.length;
    updatedBody = body.substring(0, insertIdx) + logEntry + body.substring(insertIdx);
  } else {
    updatedBody += `\n\n${auditHeader}${logEntry}`;
  }

  const serialized = serializeMarkdownState(metadata, updatedBody);
  fs.writeFileSync(filePath, serialized, 'utf8');

  console.log(`🚀 Transitioned Issue #${issueId} successfully!`);
  console.log(`New Phase:  ${metadata.current_phase}`);
  console.log(`Assignee:   ${metadata.assigned_agent}`);
  console.log(`HITL Block: ${metadata.hitl_approval_required ? 'YES 🛑' : 'NO ✅'}`);

  // --- GITHUB SYNC ON SUCCESSFUL TRANSITION ---
  let commentBody = `### 🚀 SDLC Stage Transition: \`${prevPhaseId}\` ➔ \`${nextPhase.id}\`\n`;
  commentBody += `- **Assignee**: \`${nextPhase.assignee}\`\n`;
  commentBody += `- **Status**: \`in-progress\`\n`;
  if (comment) {
    commentBody += `- **Notes**: ${comment}\n`;
  }
  
  const findings = extractFindings(prevPhaseId, issueId);
  if (findings) {
    commentBody += `\n#### 📋 Key Findings & Recommendations from \`${prevPhaseId}\`:\n\n${findings}\n`;
  }

  updateGitHubIssue(issueId, prevLabel, nextPhase.label, commentBody);
}

// Add Feedback Comment (rejection/revision loop)
function failReview(issueIdStr, rejectionNotes) {
  const issueId = Number(issueIdStr);
  const fileName = `issue_${issueId}.md`;
  const filePath = path.join(STATE_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.error(`Error: Issue file not found at ${filePath}`);
    process.exit(1);
  }

  const { metadata, body } = parseMarkdownState(filePath);
  
  // Rejection loop behavior: QA/Tech Lead rejects code implementation
  // Transitions current phase back to implementation and assigns to Senior Developer
  const prevPhase = metadata.current_phase;
  const type = metadata.type || 'feature';
  const phases = getWorkflowPhases(type);
  const prevPhaseInfo = phases.find(p => p.id === prevPhase);
  const prevLabel = prevPhaseInfo ? prevPhaseInfo.label : null;

  metadata.current_phase = 'implementation';
  metadata.assigned_agent = 'senior_developer';
  metadata.status = 'blueprint-revision';
  metadata.hitl_approval_required = false;
  metadata.hitl_approved_by = '';

  const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
  
  // Append audit log
  let updatedBody = body;
  const auditHeader = '## 📋 Audit Log & Stage Transitions';
  const auditLogIdx = body.indexOf(auditHeader);
  const logEntry = `\n- **${timestamp}**: ❌ Review REJECTED during \`${prevPhase}\`. Sent back to \`senior_developer\` for blueprint-revision.`;
  if (auditLogIdx !== -1) {
    updatedBody = body.substring(0, auditLogIdx + auditHeader.length) + logEntry + body.substring(auditLogIdx + auditHeader.length);
  }

  // Update blocker comment
  const blockerHeader = '## 🔄 Blockers & Review Feedback';
  const blockerIdx = updatedBody.indexOf(blockerHeader);
  const loopEntry = `\n### Audit Rejection Loop (${timestamp})\n- **By**: QA/Tech Lead\n- **Feedback**: ${rejectionNotes}\n- **Status**: Active Revision Needed\n`;
  if (blockerIdx !== -1) {
    updatedBody = updatedBody.substring(0, blockerIdx + blockerHeader.length) + loopEntry + updatedBody.substring(blockerIdx + blockerHeader.length);
  } else {
    updatedBody += `\n\n${blockerHeader}${loopEntry}`;
  }

  const serialized = serializeMarkdownState(metadata, updatedBody);
  fs.writeFileSync(filePath, serialized, 'utf8');

  console.log(`❌ Issue #${issueId} review rejected! Assigned back to Senior Developer.`);

  // --- GITHUB SYNC ON REJECTION ---
  const devLabelInfo = phases.find(p => p.id === 'implementation');
  const devLabel = devLabelInfo ? devLabelInfo.label : 'status:development';

  let commentBody = `### ❌ Review REJECTED in \`${prevPhase}\`\n`;
  commentBody += `- **Status**: \`blueprint-revision\`\n`;
  commentBody += `- **Assignee**: \`senior_developer\`\n\n`;
  commentBody += `#### 🔄 Rejection Feedback:\n${rejectionNotes}\n`;

  updateGitHubIssue(issueId, prevLabel, devLabel, commentBody);
}

// Help Menu
function printHelp() {
  console.log(`
Multi-Agent SDLC Orchestration Coordinator CLI

Usage:
  node coordinator.js --status                      Show active issue lifecycles and states
  node coordinator.js --transition <id> [comment]    Transition issue to the next phase
  node coordinator.js --reject <id> "<notes>"       Trigger revision loop (reassign to dev)
  node coordinator.js --help                        Display this help screen
  `);
}

// Execution Entry
function main() {
  ensureDir(STATE_DIR);
  
  const args = process.argv.slice(2);
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printHelp();
    return;
  }

  if (args.includes('--status')) {
    printStatus();
  } else if (args[0] === '--transition') {
    const id = args[1];
    if (!id) {
      console.error('Error: Please specify issue ID.');
      process.exit(1);
    }
    const comment = args[2] || '';
    transitionIssue(id, comment);
  } else if (args[0] === '--reject') {
    const id = args[1];
    const notes = args[2];
    if (!id || !notes) {
      console.error('Error: Please specify issue ID and rejection notes.');
      process.exit(1);
    }
    failReview(id, notes);
  } else {
    console.error(`Unknown argument: ${args[0]}`);
    printHelp();
  }
}

main();
