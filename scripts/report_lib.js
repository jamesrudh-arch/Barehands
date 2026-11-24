// LEVERAGE — Full Game Audit & Research-Backed Upgrade Roadmap
// English report, R1 noir cover, 3-section numbering, TOC.
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, PageBreak, Header, Footer, PageNumber, NumberFormat,
  AlignmentType, HeadingLevel, WidthType, BorderStyle, ShadingType,
  TableOfContents, TableLayoutType,
} = require("docx");
const fs = require("fs");
const sizeOf = (p) => {
  const b = fs.readFileSync(p);
  // PNG: IHDR width/height at offsets 16/20
  if (b.length > 24 && b[0] === 0x89 && b[1] === 0x50) {
    return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
  }
  // JPEG: walk the segment markers to the first SOFn frame
  let i = 2;
  while (i < b.length - 9) {
    if (b[i] !== 0xFF) { i++; continue; }
    const marker = b[i + 1];
    if (marker >= 0xC0 && marker <= 0xCF && marker !== 0xC4 && marker !== 0xC8 && marker !== 0xCC) {
      return { h: b.readUInt16BE(i + 5), w: b.readUInt16BE(i + 7) };
    }
    const segLen = b.readUInt16BE(i + 2);
    i += 2 + segLen;
  }
  return { w: 960, h: 540 }; // fallback preserves aspect safety
};

// ---------- palette (noir, on-brand with the game's design system) ----------
const P = {
  bg: "05060F", title: "E8E8F4", subtitle: "8A90B0", meta: "C8CCDF",
  accent: "00A8C8", accent2: "FF007F", footer: "8A90B0",
  body: "000000", secondary: "506070", surface: "F2F4F6",
};

const EN = { ascii: "Times New Roman", eastAsia: "Times New Roman" };
const ENH = { ascii: "Arial", eastAsia: "Arial" };

// ---------- cover helpers (from design-system.md) ----------
function splitTitleLines(title, charsPerLine) {
  if (title.length <= charsPerLine) return [title];
  const breakAfter = new Set([..." \t-_—–·/:,;"]);
  const lines = []; let remaining = title;
  while (remaining.length > charsPerLine) {
    let breakAt = -1;
    for (let i = charsPerLine; i >= Math.floor(charsPerLine * 0.6); i--) {
      if (i < remaining.length && breakAfter.has(remaining[i - 1])) { breakAt = i; break; }
    }
    if (breakAt === -1) {
      const limit = Math.min(remaining.length, Math.ceil(charsPerLine * 1.3));
      for (let i = charsPerLine + 1; i < limit; i++) {
        if (breakAfter.has(remaining[i - 1])) { breakAt = i; break; }
      }
    }
    if (breakAt === -1) breakAt = charsPerLine;
    lines.push(remaining.slice(0, breakAt).trim());
    remaining = remaining.slice(breakAt).trim();
  }
  if (remaining) lines.push(remaining);
  if (lines.length > 1 && lines[lines.length - 1].length <= 2) {
    const last = lines.pop(); lines[lines.length - 1] += last;
  }
  return lines;
}
function calcTitleLayout(title, maxWidthTwips, preferredPt = 40, minPt = 24) {
  // EN chars ~ 0.5 em: pt * 10 twips per char
  const charsPerLine = (pt) => Math.floor(maxWidthTwips / (pt * 10));
  let titlePt = preferredPt, lines;
  while (titlePt >= minPt) {
    const cpl = charsPerLine(titlePt);
    if (cpl < 2) { titlePt -= 2; continue; }
    lines = splitTitleLines(title, cpl);
    if (lines.length <= 3) break;
    titlePt -= 2;
  }
  if (!lines || lines.length > 3) { lines = splitTitleLines(title, charsPerLine(minPt)); titlePt = minPt; }
  return { titlePt, titleLines: lines };
}
function calcCoverSpacing(p) {
  const { titleLineCount = 1, titlePt = 36, hasSubtitle = false, hasEnglishLabel = false,
    metaLineCount = 0, fixedHeight = 800, pageHeight = 16838 } = p;
  const SAFETY = 1200;
  const usable = pageHeight - SAFETY;
  const content = titleLineCount * (titlePt * 23 + 200) + (hasSubtitle ? 12 * 23 + 600 : 0)
    + (hasEnglishLabel ? 9 * 23 + 600 : 0) + metaLineCount * (10 * 23 + 100) + fixedHeight + 900;
  const remaining = Math.max(usable - content, 400);
  const FOOTER_MIN = 800;
  const rawTop = Math.floor(remaining * 0.45), rawBottom = Math.floor(remaining * 0.45);
  const bottomSpacing = Math.max(rawBottom, FOOTER_MIN);
  const topSpacing = Math.max(rawTop - Math.max(0, FOOTER_MIN - rawBottom), 400);
  return { topSpacing, bottomSpacing };
}
const noBorders = { top: { style: BorderStyle.NONE }, bottom: { style: BorderStyle.NONE }, left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE } };
const allNoBorders = { ...noBorders, insideHorizontal: { style: BorderStyle.NONE }, insideVertical: { style: BorderStyle.NONE } };

function buildCoverR1(config) {
  const C = config.palette;
  const padL = 1200, padR = 800;
  const availableWidth = 11906 - padL - padR - 300;
  const { titlePt, titleLines } = calcTitleLayout(config.title, availableWidth, 40, 24);
  const titleSize = titlePt * 2;
  const spacing = calcCoverSpacing({
    titleLineCount: titleLines.length, titlePt, hasSubtitle: !!config.subtitle,
    hasEnglishLabel: !!config.englishLabel, metaLineCount: (config.metaLines || []).length,
    fixedHeight: 400,
  });
  const accentLeft = { style: BorderStyle.SINGLE, size: 8, color: C.accent, space: 12 };
  const children = [];
  children.push(new Paragraph({ spacing: { before: spacing.topSpacing } }));
  if (config.englishLabel) {
    children.push(new Paragraph({
      indent: { left: padL, right: padR }, spacing: { after: 500 },
      border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: C.accent, space: 8 } },
      children: [new TextRun({ text: config.englishLabel.split("").join("  "), size: 18, color: C.accent, font: ENH, characterSpacing: 40 })],
    }));
  }
  for (let i = 0; i < titleLines.length; i++) {
    children.push(new Paragraph({
      indent: { left: padL },
      spacing: { after: i < titleLines.length - 1 ? 100 : 300, line: Math.ceil(titlePt * 23), lineRule: "atLeast" },
      children: [new TextRun({ text: titleLines[i], size: titleSize, bold: true, color: C.title, font: ENH })],
    }));
  }
  if (config.subtitle) {
    children.push(new Paragraph({
      indent: { left: padL }, spacing: { after: 800 },
      children: [new TextRun({ text: config.subtitle, size: 24, color: C.subtitle, font: ENH })],
    }));
  }
  for (const line of (config.metaLines || [])) {
    children.push(new Paragraph({
      indent: { left: padL + 200 }, spacing: { after: 80 },
      border: { left: accentLeft },
      children: [new TextRun({ text: line, size: 24, color: C.meta, font: ENH })],
    }));
  }
  children.push(new Paragraph({ spacing: { before: spacing.bottomSpacing } }));
  children.push(new Paragraph({
    indent: { left: padL, right: padR },
    border: { top: { style: BorderStyle.SINGLE, size: 2, color: C.accent, space: 8 } },
    spacing: { before: 200 },
    children: [
      new TextRun({ text: config.footerLeft || "", size: 16, color: C.footer, font: ENH }),
      new TextRun({ text: "                                        " }),
      new TextRun({ text: config.footerRight || "", size: 16, color: C.footer, font: ENH }),
    ],
  }));
  return [new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    layout: TableLayoutType.FIXED,
    borders: allNoBorders,
    rows: [new TableRow({
      height: { value: 16838, rule: "exact" },
      children: [new TableCell({ shading: { type: ShadingType.CLEAR, fill: C.bg }, borders: noBorders, children })],
    })],
  })];
}

// ---------- body helpers ----------
function h1(text) { return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 360, after: 160, line: 312 }, children: [new TextRun({ text, bold: true, size: 32, color: "0A1628", font: ENH })] }); }
function h2(text) { return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 280, after: 120, line: 312 }, children: [new TextRun({ text, bold: true, size: 28, color: "0A1628", font: ENH })] }); }
function p(runs, opts = {}) {
  const children = (typeof runs === "string") ? [new TextRun({ text: runs, size: 24, font: EN, color: "000000" })] : runs;
  return new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { after: 120, line: 312 }, children, ...opts });
}
function b(text) { return new TextRun({ text, bold: true, size: 24, font: EN, color: "000000" }); }
function t(text) { return new TextRun({ text, size: 24, font: EN, color: "000000" }); }
function bullet(text) { return new Paragraph({ bullet: { level: 0 }, alignment: AlignmentType.LEFT, spacing: { after: 80, line: 312 }, children: [new TextRun({ text, size: 24, font: EN, color: "000000" })] }); }
function caption(text) { return new Paragraph({ alignment: AlignmentType.LEFT, spacing: { before: 40, after: 160, line: 312 }, children: [new TextRun({ text, italics: true, size: 21, color: P.secondary, font: EN })] }); }

function cell(text, o = {}) {
  return new TableCell({
    children: [new Paragraph({ spacing: { line: 276 }, children: [new TextRun({ text, bold: !!o.bold, size: o.size || 21, font: EN, color: o.color || "000000" })] })],
    shading: o.fill ? { type: ShadingType.CLEAR, fill: o.fill } : undefined,
    margins: { top: 60, bottom: 60, left: 120, right: 120 },
    width: o.width ? { size: o.width, type: WidthType.PERCENTAGE } : undefined,
  });
}
function table(headers, rows, widths) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: P.accent }, bottom: { style: BorderStyle.SINGLE, size: 2, color: P.accent },
      left: { style: BorderStyle.NONE }, right: { style: BorderStyle.NONE },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 1, color: "D0D0D0" }, insideVertical: { style: BorderStyle.NONE },
    },
    rows: [
      new TableRow({ tableHeader: true, cantSplit: true, children: headers.map((x, i) => cell(x, { bold: true, fill: "EAF4F8", width: widths ? widths[i] : undefined })) }),
      ...rows.map(r => new TableRow({ cantSplit: true, children: r.map((x, i) => cell(x, { width: widths ? widths[i] : undefined })) })),
    ],
  });
}
function tcap(text) { return new Paragraph({ keepNext: true, spacing: { before: 200, after: 80, line: 312 }, children: [new TextRun({ text, bold: true, size: 21, font: EN, color: P.secondary })] }); }

function img(path, wTwips) {
  const d = sizeOf(path);
  const hTw = Math.round(wTwips * d.h / d.w);
  return new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { before: 160, after: 60 },
    children: [new ImageRun({ type: "jpg", data: fs.readFileSync(path), transformation: { width: wTwips, height: hTw } })],
  });
}

module.exports = { Document, Packer, Paragraph, TextRun, PageBreak, Header, Footer, PageNumber, NumberFormat, AlignmentType, HeadingLevel, TableOfContents, buildCoverR1, h1, h2, p, b, t, bullet, caption, table, tcap, img, P, EN, ENH, fs };
