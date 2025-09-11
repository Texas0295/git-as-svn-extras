
# git-as-svn-extras

用於擴展 [git-as-svn](https://github.com/bozaro/git-as-svn) 的功能：

- 為 SVN 提交自動套用 **GPG 簽名**
- 一鍵 **對齊裸庫分支到遠端**（支援 fork 強制同步上游）
- 一鍵 **推送裸庫到遠端**

> 本工具假設 git-as-svn 是運行在 **bare repo** 上。

## 專案結構


```
.
├── 0001-FEA-gitwriter-GPG-Sign.patch   # 修改 GitWriter.kt，支援外部 GPG 簽名
└── scripts
	├── gasvn-align-to-origin.sh        # 對齊裸庫分支到遠端並重建 SVN timeline
	└── git-mirror-push-all.sh          # 推送裸庫到遠端

```

## 安裝與套用

### 1. 套用 GPG 簽名補丁

```bash
git -C /path/to/git-as-svn apply /path/to/0001-FEA-gitwriter-GPG-Sign.patch
# 或用 git am，視管理方式
```

重新編譯並部署 git-as-svn

這個補丁會在 SVN commit 時呼叫外部 `gpg`（或 wrapper）進行簽名，需要 git config 設定：

```bash
 git config --global commit.gpgSign true
 git config --global gpg.format openpgp
 git config --global user.signingkey <key-id-or-uid>
 git config --global gpg.program /path/to/gpg-or-wrapper
```

### 2. 安裝腳本

把 `scripts/` 目錄加到 PATH 或直接 alias，例如：

```bash
mkdir -p ~/.config/git-as-svn/scripts
cp scripts/* ~/.config/git-as-svn/scripts/
echo 'alias svnrsync="~/.config/git-as-svn/scripts/gasvn-align-to-origin.sh"' >> ~/.bashrc
echo 'alias svnpush="~/.config/git-as-svn/scripts/git-mirror-push-all.sh"' >> ~/.bashrc
```

## 使用流程

### 1. 對齊 fork 到上游狀態

假設裸庫在 `/srv/git/repositories/Solian`，要對齊 `v3` 分支到 `origin/v3`：

```bash
svnrsync Solian v3
```

功能：

* 自動 `fetch origin`
* 備份原分支到 `refs/heads/backup/...`
* 對齊到遠端指定分支
* 刪除 `refs/git-as-svn/v1/<branch>` 讓 git-as-svn 重建 SVN 修訂編號
* 清快取並重啟 git-as-svn
* 成功後刪除備份 ref（避免推送）

### 2. 推送裸庫到遠端

```bash
svnpush
```

功能：

* 推送`REPO_ROOT`\(默認爲`/srv/git/repositories`)下的所有庫到`REMOTE_NAME`\(默認爲`origin`)

## 注意事項

* 補丁與腳本假設使用 **bare repo** 作為 git-as-svn 的儲存目錄
* `svnrsync` 預設操作路徑 `/srv/git/repositories/<repo>`，可用環境變數 `REPO_ROOT` 覆蓋
* 確保 `~/.gnupg`、`gpg.program` 可在 git-as-svn 執行環境讀取，否則簽名會失敗
* 對齊操作是強制更新 refs，會覆蓋分支歷史，請確定已備份或可丟棄本地提交
