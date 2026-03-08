# Scripts

## Start Here

- [`governance/README.md`](governance/README.md)：human-run operator surface（sync / rollout / release / audit / policy probes）。
- [`verify/README.md`](verify/README.md)：gate family 入口与 canonical run order。
- [`common/README.md`](common/README.md)：shared helper API、no-BOM 写入规则、wave gate runner。
- [
outer/README.md](router/README.md)：router decision surface 与 module/legacy 结构说明。
- [overlay/README.md](overlay/README.md)：overlay suggestion surface（advice-first）。
- [erify/fixtures/README.md](verify/fixtures/README.md)：verify mock / pilot fixture 索引。

## Directory Roles

| Path | Role | Notes |
| --- | --- | --- |
| `scripts/governance/` | operator entrypoints | 会直接触及 rollout / release / mirror / policy / audit |
| `scripts/verify/` | executable gates | stop-ship / advisory / plane / release / closure families |
| `scripts/common/` | shared primitives | UTF-8 no BOM、execution-context、parity、wave runner |
| `scripts/overlay/` | overlay helper scripts | advice-first overlay / provider suggestion helpers |
| `scripts/router/` | router analysis helpers | route probing / pack routing / keyword audit support |
| `scripts/bootstrap/`, `scripts/setup/` | environment bootstrap | install / setup / compatibility helpers |
| `scripts/research/`, `scripts/learn/` | research / learning support | 非核心治理入口；按具体场景使用 |

## Cleanup-First Rules

- 不在 mirror 或 installed runtime 副本里直接运行 operator 脚本；优先从 canonical repo 执行。
- 影响 packaging / release / rollout 的改动完成后，回到 [`verify/README.md`](verify/README.md) 复跑对应 gates。
- 共享逻辑优先收敛到 [`common/README.md`](common/README.md) 所描述的 helper surface，而不是在单脚本重复实现。
