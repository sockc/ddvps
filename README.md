# DDVPS

DDVPS 是一个基于 `bin456789/reinstall` 的 VPS 重装增强菜单。

本项目不重写重装核心，只负责把常用参数做成菜单，最后调用上游 `reinstall.sh` 执行。

## 功能

- Linux 重装菜单：Debian / Ubuntu / Alpine / RHEL 系 / 其它 Linux
- Windows ISO 安装菜单：自动查找 ISO / 自定义 ISO
- 自定义 RAW/VHD 镜像 DD
- Alpine Live / netboot.xyz 救援引导
- 密码、SSH 端口、SSH 公钥、Web 观察端口、frpc、hold 模式
- 执行前显示命令、保存脱敏命令、可选保存完整命令
- OpenVZ/LXC 风险提示
- reset 取消误执行入口

## 安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/sockc/ddvps/main/install.sh)
```

安装后运行：

```bash
ddvps
```

不安装直接运行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/sockc/ddvps/main/ddvps.sh)
```

## 目录结构

```text
ddvps/
├── install.sh
├── ddvps.sh
├── lib/
│   ├── common.sh
│   ├── detect.sh
│   ├── input.sh
│   ├── runner.sh
│   └── safety.sh
├── menus/
│   ├── linux.sh
│   ├── windows.sh
│   ├── dd.sh
│   ├── rescue.sh
│   └── manage.sh
└── data/
    ├── distros.conf
    └── windows.conf
```

## 上游核心

Core reinstall engine: https://github.com/bin456789/reinstall

如果你 fork 或修改上游核心，请遵守上游 GPL-3.0 许可证。当前项目仅作为菜单壳调用上游脚本。
