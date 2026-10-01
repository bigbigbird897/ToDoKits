#!/usr/bin/env bash
# ============================================================
# ToDoKits 个人生活助手 —— Ubuntu 部署脚本（v1.1 审阅版）
# ------------------------------------------------------------
# 功能：关闭防火墙 → 安装/配置 Nginx → 安装/配置 PostgreSQL
#       → 安装花生壳（动态域名解析）→ 后端注册为 systemctl 服务并开机自启
# 用法：sudo bash deploy-ubuntu.sh
# 环境：Ubuntu（20.04 / 22.04 / 24.04 均可）
# 端口规划：
#   - 9510  Nginx 对外入口（前端静态页面）
#   - 9610  后端 API（仅本机，Nginx 反向代理到此处）
# 前置准备（本脚本只负责部署，不负责上传产物）：
#   - 前端构建产物已解压到 /var/www/todokits（含 index.html + dist）
#   - 后端 linux-x64 发布产物已放 /opt/todokits/backend
# ============================================================


# 1、sudo apt install open-vm-tools open-vm-tools-desktop -y。`open-vm-tools-desktop` 带桌面功能：共享剪贴板、拖拽文件、自动适配分辨率。
# 2、sudo apt install openssh-server；sudo ufw allow 22/tcp 用于进行远程连接
# 3、安装vim
# 4、设置允许使用远程工具，使用root账号进行登录；先给 root 设置密码sudo passwd root
# ；修改 ssh 服务配置文件sudo vim /etc/ssh/sshd_config
# #PermitRootLogin prohibit-password
# ->PermitRootLogin yes；重启 ssh 服务生效sudo systemctl restart ssh


set -e   # 任意一条命令失败立即退出，避免"半途而废"的脏状态

# ---------- 0/5 检查 root 权限 ----------
if [ "$EUID" -ne 0 ]; then
  echo "[错误] 请使用 root 权限运行：sudo bash $0"
  exit 1
fi

# ============================================================
# 1/5 关闭防火墙
# ============================================================
echo "========== 1/5 关闭防火墙 =========="
# Ubuntu 默认防火墙为 ufw。此处按需求放行对外端口；
# 若希望彻底关闭，可把下面改为 ufw disable
if command -v ufw >/dev/null 2>&1; then
  # ufw disable
  ufw allow 9510/tcp   # 前端入口端口
  ufw allow 9610/tcp   # 后端 API 端口（仅本机，Nginx 代理用）
  ufw allow 9611/tcp   # 后端 API 端口（仅本机，Nginx 代理用）
  echo "已放行 9510 / 9610 端口"
fi
# 兜底：清空 iptables 规则（不持久，重启后恢复，ufw 已足够）
# iptables -F 2>/dev/null || true

# ============================================================
# 2/5 安装并配置 Nginx
# ============================================================
echo "========== 2/5 安装并配置 Nginx =========="
apt-get update -y
apt-get install -y nginx

# 站点配置写入 /etc/nginx/sites-available/todokits
#（脚本直接写文件，等价于手动 nano 编辑那一步）
# proxy_pass 末尾的 / 是 nginx 的一个特殊规则：它会把 location /api/ 匹配到的那段前缀用 / 替换掉。
# 于是浏览器请求 /api/auth/register 被转发成 /auth/register（/api 被剥掉了）。
# 而后端的路由是带 /api 前缀的（/api/auth/register），收到 /auth/register 自然就 404。
NGINX_CONF=/etc/nginx/sites-available/todokits
cat > "$NGINX_CONF" <<'EOF'
server {
    listen 9510;                     # 对外访问端口
    server_name _;                   # 匹配任意域名/IP
    root  /var/www/todokits;         # 前端静态文件目录
    index index.html;

    # 前端路由（Vue history 模式）：找不到文件时回退 index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存 7 天
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 7d;
        add_header Cache-Control "public";
    }

    # API 反向代理到后端（127.0.0.1:9610，与 systemd 服务端口一致）
    location /api/ {
        proxy_pass http://127.0.0.1:9610;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
echo "站点配置已写入 $NGINX_CONF"

# 创建软链接到 sites-enabled，使配置生效；-f 覆盖同名旧链接
# 配置文件里写了 root /var/www/todokits；
# 配置文件通过软链接挂到 sites-enabled 被 Nginx 读取；
# Nginx 读懂了配置 → 去 /var/www/todokits 取网页文件返回给浏览器。
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/todokits

# 语法检查通过后才重载，避免配错导致 nginx 挂掉
nginx -t
systemctl enable nginx      # 开机自启
systemctl reload nginx      # 平滑重载（不中断连接）
echo "Nginx 配置完成，监听 9510 端口"

# ============================================================
# 3/5 安装并配置 PostgreSQL
# ============================================================
echo "========== 3/5 安装并配置 PostgreSQL =========="
apt-get install -y postgresql postgresql-contrib

# 启动并设置开机自启
systemctl enable --now postgresql

# 1) 设置数据库超级用户 postgres 的密码为 11
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '11';"

# 2) 创建数据库 todokits（若已存在则跳过）
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='todokits'" | grep -q 1 \
  || sudo -u postgres createdb todokits

echo "PostgreSQL 已启动：账号 postgres / 密码 11 / 数据库 todokits"
echo "后端连接串参考：Host=127.0.0.1;Port=5432;Database=todokits;Username=postgres;Password=11;"

# ============================================================
# 4/5 安装花生壳（动态域名解析 phddns）
# ============================================================
# root@lwh-VMware-Virtual-Platform:~# sudo phddns status
#  +--------------------------------------------------+
#  |          Oray PeanutHull Linux 5.3.0             |
#  +--------------------------------------------------+
#  |              Runstatus: ONLINE                   |
#  +--------------------------------------------------+
#  |              SN: oray1daba7cc61d3                |
#  +--------------------------------------------------+
#  |    Remote Management Address http://b.oray.com   |
#  +--------------------------------------------------+
echo "========== 4/5 安装花生壳（动态域名解析） =========="
# 前置工具：net-tools（提供 netstat 等）、wget（下载安装包）
apt-get install -y net-tools wget curl

# 下载花生壳 Linux amd64 安装包（5.3.0，Oray 官方源）
PHDDNS_DEB=phddns_5.3.0_amd64.deb
curl -L "https://dl.oray.com/hsk/linux/phddns_5.3.0_amd64.deb" -o phddns_5.3.0_amd64.deb

# 安装 deb 包（-y 免确认）
apt-get install -y "./$PHDDNS_DEB"

# 启动花生壳服务并开机自启
# 注：花生壳服务名一般为 phddns；若系统里实际服务名不同，改下面一行即可
systemctl enable --now phddns 2>/dev/null || {
  echo "[警告] 未找到 phddns 服务，花生壳可能安装方式不同，请手动执行：sudo phddns"
}

echo "花生壳已安装。登录账号 / 配置域名映射请在花生壳控制台或运行 phddns 交互完成"
echo "（本脚本只完成安装与开机自启，花生壳需登录对应账号后才能使用）"

# ============================================================
# 5/5 后端接口注册为 systemctl 服务（开机自启）
# ============================================================
echo "========== 5/5 后端注册为 systemctl 服务 =========="
# 后端发布目录与可执行文件名（linux-x64 自包含发布，需先手动放置）
BACKEND_DIR=/opt/todokits/backend
BACKEND_BIN="$BACKEND_DIR/ToDoKits.Controllers"
# 后端监听端口必须与 Nginx 的 proxy_pass（9610）保持一致
BACKEND_PORT=9610

# 若发布产物尚未放到位，给出提示但不中断（服务稍后可再 start）
if [ ! -f "$BACKEND_BIN" ]; then
  echo "[警告] 未找到 $BACKEND_BIN，请先把后端发布产物放到该目录"
  echo "       之后可手动执行：systemctl start todokits-api"
fi

# 写入 systemd 服务单元（等价于你给的 BackgroundServices 模板，改为 ToDoKits）
SVC=/etc/systemd/system/todokits-api.service
cat > "$SVC" <<EOF
[Unit]
Description=ToDoKits Backend WebAPI
After=network.target

[Service]
WorkingDirectory=$BACKEND_DIR
ExecStart=$BACKEND_BIN
Environment="ASPNETCORE_URLS=http://0.0.0.0:$BACKEND_PORT"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "服务单元已写入 $SVC"

# 重新加载 systemd，启用开机自启并尝试启动
systemctl daemon-reload
systemctl enable todokits-api
systemctl start todokits-api 2>/dev/null || echo "[警告] 服务启动失败，请检查 $BACKEND_BIN 是否存在"
systemctl status todokits-api --no-pager || true

# ============================================================
echo "============================================"
echo "部署脚本执行完毕。"
echo "前端入口：  http://<服务器IP>:9510"
echo "后端接口：  http://127.0.0.1:$BACKEND_PORT （systemd 服务 todokits-api）"
echo "============================================"
