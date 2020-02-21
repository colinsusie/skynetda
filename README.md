这是一个VSCode的调试插件，用于调试基于`skynet`框架的Lua程序，下面是详细的使用指南。

## 构建skynet

请使用支持调试插件的skynet：

[https://github.com/colinsusie/skynet](https://github.com/colinsusie/skynet)

这个版本和[官方的版本](https://github.com/cloudwu/skynet)完全一致，并且会一直合并最新的修改；由于skynet极其精简的内核，所以实现这个调试器并没有修改框架的代码，只是增加了几个额外的模块：

- cjson 用于和VSCode进行json格式的数据交换。
- vscdebuglog.lua 用于替代skynet默认的logger服务，使日志能输出到VSCode的控制台。
- vscdebugd.lua 一个专门和VSCode交互的lua服务。
- vscdebug.lua 注入到skynet.lua的调试模块。

skynet构建方法请看[WIKI](https://github.com/cloudwu/skynet/wiki/Build)

## 安装扩展

在VSCode的`Extensions`面板中搜索`Skynet Debugger`，安装这个插件，该插件不支持Windows，如果你在Windows下工作，那么可以通过VSCode的[Remote SSH](https://code.visualstudio.com/docs/remote/ssh)打开远程服务器上的skynet工程，然后再安装`Skynet Debugger`，此时该插件会安装在服务器上，这样就可以在Windows下编辑和调试服务器上的skynet工程。

插件的发布版只包含了在`Debian GNU/Linux 8.8(jessie)-64bit`和`macOS 10.15.2(Catalina)`下编译的可执行程序，在这两个系统中应该是可以运行起来的。其他平台则需要自己重新构建：

- 克隆代码：`git clone https://github.com/colinsusie/skynetda.git`
- 构建：`cd skynetda; make linux`
- 完成之后在`vscext/bin/linux`中有`skynetda`和`cjson.so`两个文件,需要将这两个文件拷贝到插件的安装目录中：
    - 如果是SSH远程服务器，插件目录应该在：`~/.vscode-server/extensions/colinsusie.skynet-debugger-0.9.0/bin/linux/`
    - 如果是Linux系统的本地插件，则应该在：`~/.vscode/extensions/colinsusie.skynet-debugger-0.9.0/bin/linux/`

## 配置launch.json

插件安装完毕之后，打开skynet工程，在`Run and Debug`面板中创建一个`launch.json`文件，内容如下：

```json
{
	"name": "skynet debugger",
	"type": "lua",
	"request": "launch",
	"program": "${workspaceFolder}",
	"config": "./examples/config_vsc"
},
```

其中`program`是skynet执行程序所在的**目录**，`config`是skynet运行所需的配置文件,这两个根据自己的情况设置。

## 配置skynet的config文件

要使skynet运行之后可以被调试，还需要修改一下config文件：

```lua
root = "$vscdbg_workdir/"
thread = 4
logger = "vscdebuglog"
logservice = "snlua"

logpath = "."
harbor = 0
start = "testvscdebug"	-- main script
bootstrap = "snlua bootstrap"	-- The service for bootstrap

luaservice = root.."service/?.lua;"..root.."test/?.lua;"..root.."examples/?.lua;"..root.."test/?/init.lua"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua"
lua_cpath = root .. "luaclib/?.so"
snax = root.."examples/?.lua;"..root.."test/?.lua"
cpath = root.."cservice/?.so"

vscdbg_open = "$vscdbg_open"
vscdbg_bps = [=[$vscdbg_bps]=]
```

- root设置为`$vscdbg_workdir/`，调试器会设置环境变量，skynet会用环境变量替换这个宏；当然你也可以直接设置成绝对路径。
- 所有涉及到路径的字段，都必须加上root前缀，比如`luaservice, lualoader, lua_path...`等等这些；这是因为调试器必须用绝对路径，否则路径判断会不对。
- 修改`logger`和`logservice`，将默认logger指定为`vscdebuglog`
- 加上`vscdbg_open = "$vscdbg_open"`和`vscdbg_bps = [=[$vscdbg_bps]=]`，调试器通过`$vscdbg_open`告诉skynet是否要开启调试，另外`$vscdbg_bps`是初始的断点信息，最好如示例那样用`[=[...]=]`来包含。

这一份config一般用于开发期的调试用，发布的版本再用正式的config。

## 开始调试

该插件只能调试指定的Lua服务，所以如果你想调试某个Lua服务，则要在那个服务加一句Lua代码，比如testvscdebug.lua这个服务：

```lua
require("skynet.vscdebug").start()  -- 加上这一句

local skynet = require "skynet"
skynet.start(function()
    -- 你的代码
end)
```

加好之后，就可以在代码中设置断点，然后按`F5`开始调试，效果如下图所示：

![sn1.png](vscext/images/sn1.png)

`require("skynet.vscdebug").start()`这句代码加在`skynet.start`所在的文件就可以了，之后这个服务运行到的代码都可以被调试。

如果skynet不是由调试器插件执行起来的，那么vscdebug.lua什么事也没做，所以这句代码其实可以不用删除，不会有任何效率上的损失。

## vscdebug的功能

vscdebug实现了大多数常用的调试功能：

- 它可以将skynet.error输出到`DEBUG CONSOLE`面板，点击日志还可跳转到相应的代码行；但是`print, io.stdout`就不行，调用这两个函数什么也不会输出。
- 除了可以设置普通断点外，还支持以下几种断点：
    - 条件断点：当表达式为true时停下来。
    - Hit Count断点：命中一定次数后停下来。
    - 日志断点：命中时输出日志。
- 当程序命中断点后停了下来，你就可以：
    - 查看调用堆栈。
    - 查看每一层栈帧的局部变量，自由变量。
    - 通过`WATCH`面板增加监控的表达式。
    - 可在`DEBUG CONSOLE`底部输入表达式，该表达式会在当前栈帧环境中执行，并得到结果输出。
- 支持`Step into`, `Step over`, `Step out`, `Continue`等调试命令。

## vscdebug怎么工作

编写skynet调试器的难点在于：skynet里面有很多个Lua虚拟机，并且这些虚拟机是在多个线程中运行的。要像原生调试器那样把整个程序冻住似乎有些难度，我最后决定像skynet的`DebugConsole`那样，让它在同一时刻只能调试Lua服务的一个协程，除了这个被调试的协程会停住，其他协程还是照常执行。所以断点命中后，看起来像是停下来了，其实它还在快速的处理消息。

它的实现是这样的：当一个协程的调试Hook回调时，如果命中断点，那么Hook函数会调用lua_yield停掉这个协程；接下来就可以对这个协程进行各种”观察”。此后执行`单步调试`，会使该协程执行一行后又被yield，如此重复，直到执行`继续`命令。

由于Lua服务的主协程不能yield，所以主协程不可以调试。但这个限制没什么大问题，因为skynet的主协程主要用于派发消息，具体的消息处理都在其他协程完成的。

在开发过程中，我发现了Lua的一个BUG，就是被Hook函数调用lua_yield的协程，它的CallInfo的savedpc会往前退一条指令，这就导致那一层的行数和局部变量不正确，修正方法是在`ldebug.c`：

```c
static int currentpc (CallInfo *ci) {
  lua_assert(isLua(ci));
  // 如果处于CIST_HOOKYIELD状态，应该加1。
  const Instruction *pc = (ci->callstatus & CIST_HOOKYIELD) ? ci->u.l.savedpc + 1 : ci->u.l.savedpc;
  return pcRel(pc, ci_func(ci)->p);
}
```

修改后问题解决了，这也是唯一修改过的底层代码。

Enjoy!!!