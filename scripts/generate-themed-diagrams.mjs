import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { copyFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { basename, join, resolve } from 'node:path'

const diagrams = ['layers', 'schema-minus-instance']
const imageDir = resolve('docs/modules/ROOT/images')
const config = resolve('docs/mermaid-config.json')
const puppeteerConfig = resolve('docs/puppeteer-config.json')
const check = process.argv.includes('--check')
const tools = {
  mmdc: resolve('node_modules/@mermaid-js/mermaid-cli/src/cli.js'),
  adapter: resolve('node_modules/@dev-centr/mermaid-svg-css-vars/bin/mermaid-svg-css-vars.js'),
}
const temporary = mkdtempSync(join(tmpdir(), 'uniconfig-diagrams-'))

function normalizeAccessibility(path) {
  writeFileSync(path, readFileSync(path, 'utf8').replace(/\brole="[^"]*"/, 'role="img"'), 'utf8')
}

function sourceFingerprint(name) {
  const hash = createHash('sha256')
  for (const path of [
    join(imageDir, `${name}.mmd`),
    join(imageDir, `${name}.theme.json`),
    config,
    resolve('package.json'),
    import.meta.filename,
  ]) {
    hash.update(readFileSync(path))
    hash.update('\0')
  }
  return hash.digest('hex')
}

function stamp(path, fingerprint) {
  const marker = `<!-- themed-svg-source-sha256:${fingerprint} -->`
  const svg = readFileSync(path, 'utf8').replace(/<!-- themed-svg-source-sha256:[a-f0-9]+ -->\s*/i, '')
  writeFileSync(path, svg.replace(/(<\?xml[^>]+>\s*)?/i, (declaration = '') => `${declaration}${marker}\n`), 'utf8')
}

function validate(path, mode, fingerprint) {
  const svg = readFileSync(path, 'utf8')
  if (!svg.includes(`themed-svg-source-sha256:${fingerprint}`)) {
    throw new Error(`${basename(path)} is stale; run pnpm diagrams:generate`)
  }
  for (const pattern of [/xmlns="http:\/\/www\.w3\.org\/2000\/svg"/, /\bviewBox="[^"]+"/, /\brole="img"/, /<title\b/, /<desc\b/]) {
    if (!pattern.test(svg)) throw new Error(`${basename(path)} fails the SVG contract`)
  }
  if (/<(?:script|foreignObject|iframe|object|embed)\b|\son[a-z]+\s*=/i.test(svg)) {
    throw new Error(`${basename(path)} contains unsafe active content`)
  }
  if (mode === 'standalone-adaptive' && !/prefers-color-scheme:\s*dark/.test(svg)) {
    throw new Error(`${basename(path)} lacks a dark preset`)
  }
  if (mode === 'host' && (!svg.includes('var(--themed-svg-') || svg.includes('prefers-color-scheme'))) {
    throw new Error(`${basename(path)} fails the host-mode contract`)
  }
}

try {
  for (const name of diagrams) {
    const fingerprint = sourceFingerprint(name)
    const destination = join(imageDir, `${name}.svg`)
    const hostDestination = join(imageDir, `${name}.host.svg`)
    if (check) {
      validate(destination, 'standalone-adaptive', fingerprint)
      validate(hostDestination, 'host', fingerprint)
      continue
    }

    const raw = join(temporary, `${name}.raw.svg`)
    execFileSync(process.execPath, [tools.mmdc,
      '-i', join(imageDir, `${name}.mmd`),
      '-o', raw,
      '-c', config,
      '-p', puppeteerConfig,
      '-b', 'transparent',
    ], { stdio: 'inherit' })
    normalizeAccessibility(raw)

    const generated = join(temporary, `${name}.svg`)
    const generatedHost = join(temporary, `${name}.host.svg`)
    const fixed = join(imageDir, `${name}.fixed.svg`)
    if (!check && !existsSync(fixed)) copyFileSync(join(imageDir, `${name}.svg`), fixed)
    execFileSync(process.execPath, [tools.adapter,
      '--manifest', join(imageDir, `${name}.theme.json`),
      '--dual-output',
      '--output', generated,
      '--host-output', generatedHost,
      raw,
    ], { stdio: 'inherit' })
    stamp(generated, fingerprint)
    stamp(generatedHost, fingerprint)

    for (const [source, target] of [
      [generated, destination],
      [generatedHost, hostDestination],
    ]) {
      await copyFile(source, target)
    }
  }
} finally {
  rmSync(temporary, { recursive: true, force: true })
}
