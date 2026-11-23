# tools-bootstrap

内部工作流工具的分发入口。

## 安装

Windows 10 及以上。打开 PowerShell，粘这一行：

```powershell
irm https://raw.githubusercontent.com/rainlv00/tools-bootstrap/main/install.ps1 -OutFile "$env:TEMP\tb.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\tb.ps1"
```

它会把工具装到 `%USERPROFILE%\.workbuddy\skills\`，装完重启 WorkBuddy 即可。

装过旧版会自动备份成 `<目录名>.bak-<时间戳>`。

## 安装回执

装完会打印一行「回执摘要」，并在 `%LOCALAPPDATA%\cbq-receipt\` 留一个 json。
请把它发给发布者用于登记授权。

回执只含：安装时间、机器码、公网 IP、主机名、Windows 账号、版本号。
不联网回传，不含任何文件内容。不想留就先执行 `$env:CBQ_NOREPORT = "1"` 再装。

## 网络不通

国内访问 `raw.githubusercontent.com` 常失败。安装器内置 jsDelivr 两个镜像，且第一次失败会自动关掉系统代理走直连重试，全挂会报 `E10`。

**如果第一条命令就报「基础连接已经关闭」**，说明你电脑上的系统代理挂了。两个办法：

```powershell
# 办法一：改用系统自带的 curl 下载（不走 .NET 的代理设置）
curl.exe -sL https://raw.githubusercontent.com/rainlv00/tools-bootstrap/main/install.ps1 -o "$env:TEMP\tb.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\tb.ps1"
```

```powershell
# 办法二：先关掉系统代理再跑原命令
[System.Net.WebRequest]::DefaultWebProxy = $null
irm https://raw.githubusercontent.com/rainlv00/tools-bootstrap/main/install.ps1 -OutFile "$env:TEMP\tb.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\tb.ps1"
```

还是不行就让对方直接把 `bundle.zip` 发你，然后：

```powershell
$env:CBQ_DATA = "C:\你放的路径\bundle.zip"
irm https://raw.githubusercontent.com/rainlv00/tools-bootstrap/main/install.ps1 -OutFile "$env:TEMP\tb.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\tb.ps1"
```

或者最省事：把 `bundle.zip` 解压，把里面的 `清单整理` 文件夹整个丢进 `%USERPROFILE%\.workbuddy\skills\`，重启 WorkBuddy。

## 卸载

删掉 `%USERPROFILE%\.workbuddy\skills\` 下对应目录，重启 WorkBuddy。
