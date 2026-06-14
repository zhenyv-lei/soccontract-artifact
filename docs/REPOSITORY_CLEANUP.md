# 仓库清洗与维护说明

## 当前范围

本仓库只发布本项目实际使用的两组处理器实验：

- `src/sodor2`
- `src/simpleooo`

对应的可复现实验入口位于 `verification/` 和 `results/*.tcl`。实验说明与
结论保留在 `docs/`。原始终端日志包含个人路径、服务器主机名和商业工具会话
信息，因此不在公开仓库中保留。

## 已清理内容

- 未实际使用的 BOOM、BOOM Secure、Ridecore、DarkRISCV 和 SimpleOoO
  单周期模型。
- 对应于上述处理器的验证脚本和原始 artifact 的批量比较脚本。
- JasperGold 生成的工程目录、数据库、缓存、JDB 文件和原始终端日志。
- JasperGold 工具手册、临时截图、个人绘图和论文写作中间文件。
- 与远程服务器和 Dask 集群绑定的个人辅助脚本。

这些内容仍可从清洗前的 Git 历史中恢复，但不应继续出现在发布分支的最新
版本中。

## 保留与忽略规则

提交以下内容：

- RTL、验证顶层和人工维护的 TCL 脚本。
- 能说明实验配置、结果和结论的 Markdown 文档。
- 人工整理且不包含运行环境信息的结果摘要。

不要提交以下内容：

- `my_proj_*`、`jgproject*`、`my_jdb_*` 等 JasperGold 生成物。
- 工具安装包、商业工具手册或许可证文件。
- 编辑器配置、临时截图、锁文件和波形文件。
- 仅适用于个人服务器路径或账号的脚本。

## 后续清洗流程

每次准备公开发布前执行：

```sh
git status --short
git ls-files | sort
git grep -nE '(/home/|/Users/|everest|comp\.nus\.edu\.sg)'
git grep -nEi '(password|passwd|token|secret|license)'
```

然后确认：

1. 所有 `verification/*.tcl` 引用的源文件仍存在。
2. README 中列出的命令可以从仓库根目录启动。
3. 新增结果仅包含必要的摘要，不包含完整 JasperGold 工程数据库。
4. 上游代码的许可证和来源说明保持完整。

## 发布历史注意事项

当前清洗只删除发布分支最新版本中的文件，不会从既有 Git 历史中抹除它们。
如果目标是让工具手册、日志、个人路径等内容无法通过历史提交下载，建议将
当前清洗后的工作树作为一个全新的公开仓库发布。只有必须保留原提交历史时，
才使用 `git filter-repo` 重写历史；历史重写会改变全部提交哈希，执行前必须
备份并与协作者确认。
