这是一个 VSCode 的调试插件，用于调试`Skynet`中的Lua程序。

## 更新说明

最新版的插件增加了工作目录(workdir)的设置，需要配合最新的skynet版本，请看下面的详细说明。

如果有用 skynet debugger 1.0.0 版的，升级到 skynet debugger 1.0.1 之后可能无法调试，需作如下处理：

- 升级到最新的[skynet](https://github.com/colinsusie/skynet)
- 把原工程的 launch.json 删除掉，重新在 VSCode 下创建launch.json，并设置相关的路径。

## 构建skynet

要想支持调试功能，你必须使用这个skynet版本：

[https://github.com/colinsusie/skynet](https://github.com/colinsusie/skynet)

这个版本和[官方的版本](https://github.com/cloudwu/skynet)完全一致，并且会一直合并最新的修改；由于skynet极其精简的内核，所以实现这个调试器并没有修改框架的代码，只是增加了几个额外的模块。skynet的构建方法请看[WIKI](https://github.com/cloudwu/skynet/wiki/Build)。


## 安装扩展

接下来在VSCode的`Extensions`面板中搜索`Skynet Debugger`安装这个插件，**该插件不支持Windows，如果你在Windows下工作，那么可以通过VSCode的[Remote SSH](https://code.visualstudio.com/docs/remote/ssh)打开远程服务器上的skynet工程，然后再安装`Skynet Debugger`，此时插件会安装在服务器上，这样就可以在Windows下编辑和调试服务器上的skynet工程。**

插件的发布版只包含了在`Debian GNU/Linux 10 (buster)`和`macOS 10.15.2(Catalina)`下编译的可执行程序，在这两个系统中应该是可以运行起来的。

其他平台先试试是否可以调试，如果不能则需要自己重新构建插件的执行程序：

- 克隆代码：`git clone https://github.com/colinsusie/skynetda.git`
- 构建：`cd skynetda; make linux`
- 完成之后在`vscext/bin/linux`中有`skynetda`和`cjson.so`两个文件,需要将这两个文件拷贝到插件的安装目录去：
    - 如果是SSH远程服务器，插件目录应该在：`~/.vscode-server/extensions/colinsusie.skynet-debugger-x.x.x/bin/linux/`
    - 如果是本地Linux，则应该在：`~/.vscode/extensions/colinsusie.skynet-debugger-x.x.x/bin/linux/`
	- 如果是MacOS，则应该是：`~/.vscode/extensions/colinsusie.skynet-debugger-x.x.x/bin/macosx/`
    - 上面的x.x.x替换为具体的版本号

## 配置launch.json

插件安装完毕之后，用VSCode打开skynet工程，在`Run and Debug`面板中创建一个`launch.json`文件，内容如下：

```json
{
	"name": "skynet debugger",
	"type": "lua",
	"request": "launch",
	"workdir": "${workspaceFolder}",
	"program": "./skynet",
	"config": "./examples/config_vsc",
	"service": "./service"
}
```

- `workdir` 是当前的工作目录，默认为 VSCode 打开的这个目录；这个目录就是程序运行起来的工作目录。
- `program` 是skynet可执行程序的路径，相对于workdir；也可以用绝对路径。注意是可执行文件的路径，不是目录；这和旧版本的含义不同。
- `config` 是skynet运行的配置文件，相对于workdir；也可以用绝对路径。
- `service` 是skynet内部服务的路径，相对于workdir，配置这个是为了过滤掉skynet内部服务的调试。

config_vsc文件的内容如下：

```lua
root = "./"
thread = 4
logger = "vscdebuglog" -- 将默认logger指定为`vscdebuglog`
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
```

- 指定 logger 为 vscdebuglog，这样在 VSCode 的 `DEBUG CONSOLE` 才能看到日志输出。
- root 为skynet的根目录，这个目录是相对于上面 workdir 的。
- 这一份配置一般用于开发期的调试使用，发布的版本要用正式的config。

## 开始调试

到这里准备工作已经完毕，你可以在代码(比如：testvscdebug)中设置断点，然后按`F5`开始调试，效果如下图所示：

![sn1.png](vscext/images/sn1.png)

该插件只能调试外部写的服务，`skynet/sevice` 目录中的服务不可调试。

如果F5之后没有成功调试，你可以CD到插件目录，比如：

- `~/.vscode-server/extensions/colinsusie.skynet-debugger-x.x.x/bin/linux/` 或
- `~/.vscode/extensions/colinsusie.skynet-debugger-x.x.x/bin/linux/`或
- `~/.vscode/extensions/colinsusie.skynet-debugger-x.x.x/bin/macosx/`

里面有一个debug.log文件，查看里面的文件，查找错误原因。

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
