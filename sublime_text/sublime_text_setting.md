##常用插件
###1. pacakage controll

从菜单 View - Show Console 或者 ctrl + ~ 快捷键，调出 console。将以下 Python 代码粘贴进去并 enter 执行，不出意外即完成安装。以下提供 ST3 和 ST2 的安装代码：

Sublime Text 3：

import urllib.request,os; pf = 'Package Control.sublime-package'; ipp = sublime.installed_packages_path(); urllib.request.install_opener( urllib.request.build_opener( urllib.request.ProxyHandler()) ); open(os.path.join(ipp, pf), 'wb').write(urllib.request.urlopen( 'http://sublime.wbond.net/' + pf.replace(' ','%20')).read())

Sublime Text 2：

import urllib2,os; pf='Package Control.sublime-package'; ipp = sublime.installed_packages_path(); os.makedirs( ipp ) if not os.path.exists(ipp) else None; urllib2.install_opener( urllib2.build_opener( urllib2.ProxyHandler( ))); open( os.path.join( ipp, pf), 'wb' ).write( urllib2.urlopen( 'http://sublime.wbond.net/' +pf.replace( ' ','%20' )).read()); print( 'Please restart Sublime Text to finish installation')

###2. 左侧目录树与背景色同步

安装SyncedSidebar，
自动同步侧边栏底色为编辑窗口底色。
###3. 高亮显示匹配括号、标签等
BracketHighlighter

###4. ConvertToUTF8

###5. Pretty Json
提供漂亮的json语法界面

###6. Markdown Preview
可以直接打开编辑Markdown

###7. 左侧目录树的字体
PackageResourceView

ctrl+shift+p -> PackageResourceViewe -> Theme-Default ->  Default.sublimt-theme -> 360L改成下面这种

```js
{
        "class": "sidebar_label",
        "color": [0, 0, 0],
        "font.bold": false,
        "font.italic": false,
        "font.size": 16,
        "font.face": "consolas",
        // , "shadow_color": [250, 250, 250], "shadow_offset": [0, 0]
},
```

###8. 调整边栏的样式

[地址](https://packagecontrol.io/packages/Boxy%20Theme)

1. Ctrl+Shift+P -> install package--"Boxy Theme"
2.  加入配置

```json
	"color_inactive_tabs": true,  //编辑区文件栏的样式
	"enable_highlight": true,
	"enable_mathjax": true,
	"line_padding_bottom": 1, //编辑区的上下行距
	"line_padding_top": 1,
	"tabs_small": true,  //编辑区文件栏的大小
	"theme": "Afterglow.sub lime-theme",   //侧边栏的主题样式

``` 
之后可以在preference->Color Theme->Theme-Afterglow中调节，当然也可以尝试一下别的主题，只要install进去，可以自行search

## 个人快捷键设置 key-bindings
`windows`

```json
	[
		{ "keys": ["ctrl+d"], "command": "run_macro_file", "args": {"file": "res://Packages/Default/Delete Line.sublime-macro"} },
		{ "keys": ["alt+q"], "command": "commit_completion", "context":
			[
				{ "key": "auto_complete_visible" },
				{ "key": "setting.auto_complete_commit_on_tab" }
			]
		},
		{ "keys": ["alt+up"], "command": "swap_line_up" },
		{ "keys": ["alt+down"], "command": "swap_line_down" },
	]
```	
	
`mac`

```json
	[
		{ "keys": ["super+d"], "command": "run_macro_file", "args": {"file": "res://Packages/Default/Delete Line.sublime-macro"} },
		{ "keys": ["alt+q"], "command": "commit_completion", "context":
			[
				{ "key": "auto_complete_visible" },
				{ "key": "setting.auto_complete_commit_on_tab" }
			]
		},
		{ "keys": ["super+up"], "command": "swap_line_up" },
		{ "keys": ["super+down"], "command": "swap_line_down" },
	]
```

##Preference
```json
[
	"font_face": "monaco",
	"font_size": 17,
	"ignored_packages":
	[
		"Vintage"
	],
	"tab_size": 4,
	"translate_tabs_to_spaces": true,
	"bold_folder_labels": false,
	
]
```

##破解
—– BEGIN LICENSE —–
Anthony Sansone
Single User License
EA7E-878563
28B9A648 42B99D8A F2E3E9E0 16DE076E
E218B3DC F3606379 C33C1526 E8B58964
B2CB3F63 BDF901BE D31424D2 082891B5
F7058694 55FA46D8 EFC11878 0868F093
B17CAFE7 63A78881 86B78E38 0F146238
BAE22DBB D4EC71A1 0EC2E701 C7F9C648
5CF29CA3 1CB14285 19A46991 E9A98676
14FD4777 2D8A0AB6 A444EE0D CA009B54
—— END LICENSE ——
 
—– BEGIN LICENSE —–
Alexey Plutalov
Single User License
EA7E-860776
3DC19CC1 134CDF23 504DC871 2DE5CE55
585DC8A6 253BB0D9 637C87A2 D8D0BA85
AAE574AD BA7D6DA9 2B9773F2 324C5DEF
17830A4E FBCF9D1D 182406E9 F883EA87
E585BBA1 2538C270 E2E857C2 194283CA
7234FF9E D0392F93 1D16E021 F1914917
63909E12 203C0169 3F08FFC8 86D06EA8
73DDAEF0 AC559F30 A6A67947 B60104C6
—— END LICENSE ——