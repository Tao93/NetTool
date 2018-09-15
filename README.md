#### What's this
macOS 状态栏显示实时网速的小工具。

#### TODO
点击状态栏时，显示各个程序的实时网速。

#### 原理：
使用 macOS 中的 nettop 命令，即可查看当前时刻各进程已经 download 和 upload 的字节数，持续按时执行 nettop 命令然后求差，即可得知网速详情。
