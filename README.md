# keyboard_listener

这个仓库现在包含三层内容：

- [prototype](prototype)：最初的 Python 键盘计数器与终端 UI
- [backend](backend)：FastAPI + SQLAlchemy + Alembic 后端，可部署到 Railway
- [macos-app](macos-app)：SwiftUI 菜单栏 macOS 客户端，负责本地采集、SQLite 缓存和批量同步

## Backend

环境变量：

- `DATABASE_URL`
- `BOOTSTRAP_SECRET`
- `API_BASE_URL`
- `APP_ENV`

本地启动：

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

测试：

```bash
cd backend
pytest
```

## macOS App

客户端源码位于 `macos-app/`，使用 Swift Package 组织，方便直接在 Xcode 中打开 `Package.swift` 继续开发。

建议流程：

```bash
cd macos-app
swift build
```

首次运行后需要授予 Accessibility 权限，客户端会把键盘事件元数据写入本地 SQLite，并按批次同步到后端。
