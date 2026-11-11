$ErrorActionPreference = "Stop"
rustup target add x86_64-pc-windows-msvc
cargo build --release --target x86_64-pc-windows-msvc
Copy-Item "target\x86_64-pc-windows-msvc\release\neuromesh_core.dll" `
          "flutter_app\windows\runner\neuromesh_core.dll" -Force
