# AGENTS.md

SAE J1979 OBD-II 服务的纯 Racket 实现（MIT，已上架 Racket catalog）。

## 结构

Multi-collection 包：collection 即 `obd2/` 子目录，scribblings 声明在 `obd2/info.rkt`（collection 级）。

## 常用命令

```bash
raco pkg install --auto --link "$(pwd)"
raco test -p obd2
```

## 验证与发版

- CI（`ci.yml`）：即上面两条命令，三平台跑。
- 发版 = tag `v<版本>` + CHANGELOG 同步；catalog 侧为手动提交（pkgd）。

## 仓库特定规矩

- 依赖 `uds` 包（catalog 依赖链）；uds 升级 pin 后本包须连测。
