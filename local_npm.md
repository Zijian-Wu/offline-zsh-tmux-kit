# Remote Ubuntu 本地安装 Node.js / npm

适用于：无 sudo 权限、远程 Ubuntu、多机器复用、希望 Node.js/npm 安装在自己用户目录下。

推荐方案：使用 `nvm` 安装本地 Node.js 和 npm。

---

## 1. 安装 nvm

```bash
cd ~
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
```

安装完成后，让当前 shell 生效。

如果使用 `bash`：

```bash
source ~/.bashrc
```

如果使用 `zsh`：

```bash
source ~/.zshrc
```

检查是否安装成功：

```bash
command -v nvm
```

正常输出：

```bash
nvm
```

---

## 2. 安装 Node.js / npm

安装 LTS 版本：

```bash
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'
```

检查版本和路径：

```bash
node -v
npm -v
which node
which npm
```

正常情况下路径应类似：

```bash
/home/MY_NAME/.nvm/versions/node/xxx/bin/node
/home/MY_NAME/.nvm/versions/node/xxx/bin/npm
```

这说明 Node.js 和 npm 都安装在当前用户目录下，不依赖 sudo。

---

## 3. zsh 中找不到 nvm 的处理

确认 `~/.zshrc` 中有以下内容：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

然后执行：

```bash
source ~/.zshrc
```

---

## 4. 如果远程服务器无法访问 GitHub

如果已经通过 SSH / VS Code Remote SSH 把本地代理反向转发到远程，例如远程可访问 `127.0.0.1:7897`，可以临时设置代理：

```bash
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897
```

然后重新执行安装命令：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
```

检查代理是否生效：

```bash
curl -I https://github.com
```

---

## 5. npm 下载慢时设置镜像源

可选：设置 npm 镜像源。

```bash
npm config set registry https://registry.npmmirror.com
```

查看当前源：

```bash
npm config get registry
```

恢复官方源：

```bash
npm config set registry https://registry.npmjs.org/
```

---

## 6. 常用命令

查看已安装 Node.js 版本：

```bash
nvm ls
```

查看可安装版本：

```bash
nvm ls-remote
```

切换版本：

```bash
nvm use --lts
```

安装指定版本：

```bash
nvm install 20
nvm use 20
```

设置默认版本：

```bash
nvm alias default 20
```

全局安装 npm 包：

```bash
npm install -g PACKAGE_NAME
```

查看全局 npm 包安装位置：

```bash
npm root -g
npm bin -g
```

---

## 7. 不推荐做法

不推荐：

```bash
sudo apt install nodejs npm
```

原因：

* apt 源中的 Node.js/npm 版本可能较旧
* 会安装到系统目录
* 需要 sudo 权限
* 后续全局 npm 包容易出现权限问题

也不推荐：

```bash
sudo npm install -g PACKAGE_NAME
```

原因：

* 容易污染系统环境
* 容易造成 npm 权限混乱

---

## 8. 推荐最终检查

```bash
command -v nvm
node -v
npm -v
which node
which npm
npm config get registry
```

如果 `which node` 和 `which npm` 都在 `~/.nvm/` 下，说明配置正确。
