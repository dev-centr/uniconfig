# UniConfig Config Panel — agent notes

- Product name: **UniConfig Config Panel**. Binary: `uniconfig`. Sibling engine: `uniconfig-core`.
- Default GUI: dlangui `default` (git pin matching DevCentr). Experimental Vello lives on the dlang-supplemental dlangui `vello-windows` config + sibling `vello-d`; enable locally when that tree is next to the app. Do not fail CI on it.
- Profiles: `profiles/catalog.sdl` + `*.schema.json`. Do not invent Terraform resource HCL in v0.1; tfvars only.
- User registry: `%LOCALAPPDATA%\UniConfig\registry.sdl` — never commit it.
- Docs contribute to docs.devcentr.org (`uniconfig` component). No second public Antora site.
- Version stamp: `source/uniconfig/app/versioninfo.d` must match git tags.
