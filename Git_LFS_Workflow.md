# Git LFS 工作流详解

## 场景：在 Repo A 中添加 1GB video.mp4

### 1. **初始设置（首次使用）**
```bash
# 进入仓库
cd repo-A

# 安装并初始化 LFS（如果还没做）
git lfs install

# 指定要跟踪的文件类型
git lfs track "*.mp4"

# 检查跟踪规则
cat .gitattributes
# 应该看到: *.mp4 filter=lfs diff=lfs merge=lfs -text
```

### 2. **添加大文件工作流**
```bash
# 1. 复制 video.mp4 到仓库根目录
cp /path/to/video.mp4 ./

# 2. 添加文件（LFS 会自动处理）
git add video.mp4

# 3. 确认文件被 LFS 正确跟踪
git lfs ls-files
# 应该显示: xxxxxxxx * video.mp4

# 4. 提交
git commit -m "Add large video file via LFS"

# 5. 推送到远程
git push origin main
```

## 完整示例流程

```bash
# 从头开始的完整示例
cd repo-A

# 设置 LFS
git lfs install
git lfs track "*.mp4" "*.mov" "*.avi"
git add .gitattributes
git commit -m "Configure LFS for video files"

# 添加大文件
cp ~/Downloads/large-video.mp4 ./video.mp4

# 验证 LFS 处理
git add video.mp4
git lfs ls-files  # 应该显示 video.mp4 被跟踪

# 提交和推送
git commit -m "Add 1GB video file"
git push origin main
```

## 团队成员协作流程

### 克隆包含 LFS 文件的仓库
```bash
# 普通克隆（会自动下载 LFS 文件）
git clone https://github.com/username/repo-A.git

# 或者分步克隆（先不下载 LFS 文件）
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/username/repo-A.git
cd repo-A
git lfs pull  # 手动下载 LFS 文件
```

### 日常使用
```bash
# 拉取更新（包括 LFS 文件）
git pull
git lfs pull

# 检查 LFS 文件状态
git lfs status
git lfs ls-files
```

## 关键注意事项

### ✅ **必须做的**：
1. **先配置 LFS 跟踪规则**，再添加大文件
2. **提交 .gitattributes 文件**
3. 使用常规 git 命令（add/commit/push），LFS 自动处理

### ❌ **避免做的**：
1. 不要在没有 LFS 跟踪的情况下添加大文件
2. 不要手动修改 .git/lfs 目录
3. 不要忽略 .gitattributes 文件

## 验证 LFS 是否正常工作

```bash
# 检查文件是否真的是指针
cat video.mp4 | head -n 1
# 应该显示类似: version https://git-lfs.github.com/spec/v1

# 查看实际文件大小 vs 仓库大小
ls -lh video.mp4                    # 实际文件大小
du -sh .git                         # 仓库大小（应该较小）
```

## 问题排查

```bash
# 如果文件没有被 LFS 正确跟踪
git lfs migrate import --include="*.mp4" --everything

# 检查 LFS 环境
git lfs env

# 查看 LFS 文件详情
git lfs ls-files --long
```

**记住核心原则**：配置好 LFS 跟踪规则后，大文件的使用体验和普通小文件完全一样！
