#!/usr/bin/env node
/**
 * Validates Word document.xml structure after generation patterns.
 * Usage: node scripts/validate-docx-xml.mjs path/to/file.docx
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const PizZip = require('pizzip');

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PHOTO_ROW_RE = /<w:tr[^>]*>(?:(?!<\/w:tr>)[\s\S])*?tempOne[\s\S]*?<\/w:tr>/;
const TEMP_THREE_RUN_RE =
  /<w:r\b[^>]*>(?:(?!<\/w:r>)[\s\S])*?tempThree(?:(?!<\/w:r>)[\s\S])*?<\/w:r>/;

const WT_OPEN = /<w:t(?:\s|>|\/)/g;

function countInvalidTextRuns(xml) {
  let bad = 0;
  for (const m of xml.matchAll(WT_OPEN)) {
    const start = m.index;
    const openEnd = xml.indexOf('>', start);
    const end = xml.indexOf('</w:t>', openEnd);
    if (end === -1) continue;
    const body = xml.slice(openEnd + 1, end);
    if (
      body.includes('<w:drawing') ||
      body.includes('<w:tbl') ||
      body.includes('<w:p ') ||
      body.includes('<w:p>') ||
      body.includes('<w:r ')
    ) {
      bad += 1;
    }
  }
  return bad;
}

function validateDocumentXml(xml) {
  const issues = [];
  if (countInvalidTextRuns(xml) > 0) {
    issues.push('block elements nested inside w:t (invalid Word structure)');
  }
  if (/<w:t[^>]*>\s*<w:r[\s>]/i.test(xml)) {
    issues.push('w:r nested directly inside w:t');
  }
  const tblOpen = (xml.match(/<w:tbl[\s>]/g) || []).length;
  const tblClose = (xml.match(/<\/w:tbl>/g) || []).length;
  if (tblOpen !== tblClose) {
    issues.push(`unbalanced tables: ${tblOpen} open, ${tblClose} close`);
  }
  return issues;
}

/** Simulate photo row replacement on template fragment */
function simulatePhotoInsert(row, imageSnippet) {
  if (TEMP_THREE_RUN_RE.test(row)) {
    return row.replace(TEMP_THREE_RUN_RE, imageSnippet);
  }
  return row.split('tempThree').join(imageSnippet);
}

function main() {
  const docxPath = process.argv[2];
  if (!docxPath) {
    console.error('Usage: node scripts/validate-docx-xml.mjs <file.docx>');
    process.exit(1);
  }
  const buf = fs.readFileSync(docxPath);
  const zip = new PizZip(buf);
  const xml = zip.file('word/document.xml')?.asText() || '';
  const issues = validateDocumentXml(xml);
  console.log('File:', path.basename(docxPath));
  console.log('document.xml length:', xml.length);
  console.log('Invalid w:t runs:', countInvalidTextRuns(xml));
  if (issues.length) {
    console.error('ISSUES:', issues.join('; '));
    process.exit(1);
  }
  console.log('OK — no invalid w:t nesting detected');

  const match = xml.match(PHOTO_ROW_RE);
  if (match) {
    const fakeImg =
      '<w:r><w:drawing><wp:inline><wp:extent cx="1" cy="1"/></wp:inline></w:drawing></w:r>';
    const out = simulatePhotoInsert(match[0], fakeImg);
    const simIssues = validateDocumentXml(out);
    if (simIssues.length) {
      console.error('SIMULATION after tempThree replace:', simIssues.join('; '));
      process.exit(1);
    }
    console.log('OK — simulated tempThree replacement keeps valid structure');
  }
}

main();
