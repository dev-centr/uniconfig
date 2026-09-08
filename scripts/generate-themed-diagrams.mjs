import { execFileSync } from 'node:child_process'
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { copyFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { basename, join, resolve } from 'node:path'

const diagrams = ['layers', 'schema-minus-instance']
const imageDir = resolve('docs/modules/ROOT/images')
const config = resolve('docs/mermaid-config.json')
const check = process.argv.includes('--check')
const tools = {
  mmdc: resolve('node_modules/@mermaid-js/mermaid-cli/src/cli.js'),
  adapter: resolve('node_modules/@dev-centr/mermaid-svg-css-vars/bin/mermaid-svg-css-vars.js'),
}
const temporary = mkdtempSync(join(tmpdir(), 'uniconfig-diagrams-'))

function normalizeAccessibility(path) {
  writeFileSync(path, readFileSync(path, 'utf8').replace(/\brole="[^"]*"/, 'role="img"'), 'utf8')
}

try {
  for (const name of diagrams) {
    const raw = join(temporary, `${name}.raw.svg`)
    execFileSync(process.execPath, [tools.mmdc,
      '-i', join(imageDir, `${name}.mmd`),
      '-o', raw,
      '-c', config,
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

    for (const [source, destination] of [
      [generated, join(imageDir, `${name}.svg`)],
      [generatedHost, join(imageDir, `${name}.host.svg`)],
    ]) {
      if (check) {
        if (readFileSync(source, 'utf8') !== readFileSync(destination, 'utf8')) {
          throw new Error(`${basename(destination)} is stale; run pnpm diagrams:generate`)
        }
      } else {
        await copyFile(source, destination)
      }
    }
  }
} finally {
  rmSync(temporary, { recursive: true, force: true })
}
