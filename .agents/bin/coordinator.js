#!/usr/bin/env node

/**
 * Antigravity Multi-Agent SDLC Coordinator
 * Pure Node.js CLI to parse filesystem state, execute transitions, and simulate loops.
 */

const fs = require('fs');
const path = require('path');

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

// Get the issue life cycle path from AGENTS.md
function getWorkflowPhases(issueType) {
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
      { id: 'merge_approval', assignee: 'coordinator', label: 'status:blocked' }
    ],
    bug: [
      { id: 'triage', assignee: 'coordinator', label: 'type:bug' },
      { id: 'qa_reproduction', assignee: 'qa_engineer', label: 'status:qa-validation' },
      { id: 'blueprinting', assignee: 'tech_lead', label: 'status:blueprint' },
      { id: 'implementation', assignee: 'senior_developer', label: 'status:development' },
      { id: 'qa_validation', assignee: 'qa_engineer', label: 'status:qa-validation' },
      { id: 'merge_approval', assignee: 'coordinator', label: 'status:blocked' }
    ],
    refactor: [
      { id: 'triage', assignee: 'coordinator', label: 'type:refactor' },
      { id: 'architecture_design', assignee: 'system_architect', label: 'status:tech-design' },
      { id: 'blueprinting', assignee: 'tech_lead', label: 'status:blueprint' },
      { id: 'implementation', assignee: 'senior_developer', label: 'status:development' },
      { id: 'qa_validation', assignee: 'qa_engineer', label: 'status:qa-validation' },
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

  if (currentPhaseIndex >= phases.length - 1) {
    console.log(`✅ Issue #${issueId} is already in the final phase: ${metadata.current_phase}.`);
    return;
  }

  const nextPhase = phases[currentPhaseIndex + 1];
  
  // Apply update
  const prevPhaseId = metadata.current_phase;
  metadata.current_phase = nextPhase.id;
  metadata.assigned_agent = nextPhase.assignee;
  metadata.status = 'in-progress';
  
  // Reset approval tags for next phase gates
  // In a real framework, we'd check if nextPhase requires HITL and set:
  // metadata.hitl_approval_required = nextPhase.hitl_gate;
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
