# 快乐英语（小学英语学习 App）

给孩子做的离线英语学习 App，对齐天津地区教材（新蕾版 1–2 年级 / 人教精通版 3–6 年级）。Flutter 开发，纯本地运行，无网络、无广告、无账号。

## 功能

- **课文点读**：按单元展示课文句子，点按钮听标准发音（含慢速版）
- **单词学习**：大图 + 单词 + 中文释义，喇叭按钮发音
- **跟读打分**：孩子对着麦克风读，本地 Vosk 离线识别 + 词级比对打分（0–100 分 + 星级）
- **满分知识卡**：跟读 ≥85 分弹出一道小知识（生物 / 冷知识 / 成语 / 地理 / 历史 / 脑筋急转弯 / 生活常识 / 科学，共 916 道），每题一轮只弹一次
- **进度本地保存**：SQLite 记录每一项的星级和是否已学

## 内容盘点（2026-11 实测）

12 册、1470 个条目（883 句 + 587 词），883 个句子每句都有慢速版。

| 册 | 年级 | 条目 | 配图现状 |
|---|---|---|---|
| book1 | 一上 | 135 | 135 张一对一（512 WebP）✅ |
| book2 | 一下 | 219 | 219 张一对一（512 WebP）✅ |
| book3 | 二上 | 191 | **仅 6 张单元封面**，单图最多被 45 条共用 ⚠️ |
| book4 | 二下 | 205 | **仅 6 张单元封面**，单图最多被 52 条共用 ⚠️ |
| book5–12 | 三–六 | 672 | 672 张一对一，但为 800×800，与低年级不一致 |

- **语音**：883 句统一 `en-GB-LibbyNeural`（rate -10%，24kHz 单声道），慢速版 atempo 0.85
- **单词音**：一年级 61 个已统一为同一规格；二年级混采样率；三–六年级为 44.1kHz 旧音源
- **打分模型**：Vosk small en-us，39MB，打包在 APK 内

## 目录结构

```
快乐英语_一年级上下册_音色统一版.apk   当前最新交付包（175MB，不进版本库）

快乐英语/
  kuaile_yingyu/          # Flutter 工程（唯一代码位置）
    lib/                  # 页面 / 服务 / 数据模型
      pages/              # 年级选择、册选择、单元、课文点读、单词、跟读、设置
      services/           # 音频播放、打分、语音识别、知识卡
      data/               # 模型、进度库、内容加载
    assets/
      data/content.json   # 教材内容（12 册）
      data/riddles/       # 916 道知识卡 JSON
      audio/              # 发音音频 + _slow 慢速版
      images/             # 插图（book1/book2 逐条配图）
    test/                 # 单元测试
    tool/check_assets.py  # 资源门禁脚本
  文档/                   # 测试报告、验收清单、审定报告、上架步骤
  历史包/                 # 上一版两个安装包，留作对照

工具/
  脚本/                   # 26 个可复用脚本（见下）
  归档/
    map/                  # 22 份配图 URL 映射，可追溯每张图的来源
    过程脚本/             # 一次性探索脚本，仅作历史参考
    审计记录/             # 音频/图片审计结果、Libby 合成日志
    抽检图/               # 配图人工抽检留证
  试听_book1/             # 语音音色试听样本

学生习题/                 # 笔顺跟写练习、每日一练、期末卷
需求文档/                 # 需求/设计/选型/POC 文档 + 素材资源包
_教材录音/                # 录音清单 CSV
.github/workflows/        # CI 门禁
```

`E:\he_app` 是指向 `快乐英语/kuaile_yingyu` 的 junction，flutter 命令在那里执行。

## 构建与门禁

顺序固定，前一步不过不往下走：

```powershell
$env:Path = $env:Path + ";D:\dev\flutter\bin"

cd E:\he_app
python tool/check_assets.py      # problems 必须 0，且 slow_files == sentences
flutter analyze --no-pub         # 静态分析
flutter test --no-pub            # 单元测试（12 条）
flutter build apk --release --target-platform android-arm64
```

产物：`build/app/outputs/flutter-apk/app-release.apk`，当前约 175MB（arm64 单架构，Android 8.0+）。

## 脚本清单（工具/脚本/）

**配图与语音**

| 脚本 | 用法 |
|---|---|
| `apply_imgs.py` | `<map.json> <bookdir> <book_id>` 按映射落盘 512 WebP。**第 3 个参数必传**，否则跨册同名 id 互相污染；会跳过已存在文件 |
| `batch_libby.py` | `<MAXBOOK> <MINBOOK>` 批量重做句子音频 + 慢速版 |
| `batch_words.py` | 批量重做一年级单词音频（仅 book1/2） |
| `dump_units.py` | `<book_id> <unit_id>` 打印单元全部文本，写配图提示词前先跑 |
| `compress_images.py` / `trim_silence.py` / `probe_audio.py` | 图片压缩、音频去静音、音频探测 |

**验收与审计**

| 脚本 | 用法 |
|---|---|
| `verify_b12.py` / `verify_b12b.py` | 核对各册条目数、唯一位图数、尺寸分布 |
| `audit_b12_full.py` / `audit_slow_riddle.py` | 全量审计：慢速缺口、知识卡 key 验证 |

**期末卷与笔顺（产物写回 `学生习题/`）**

改内容改脚本，不要手工改成品。

| 脚本 | 作用 |
|---|---|
| `gen_exams2.py` | 生成四份卷（语文/数学 × 基础/提高） |
| `gen_answers.py` | 生成参考答案（每卷 1 页） |
| `exam_lib.py` | 公共版式库：A4、得分表、页码域、米字格、写话方格 |
| `render_any.py` | 用 WPS 转 PDF 并打印页数 |
| `audit_final.py` / `audit_fill2.py` / `audit_ink4.py` / `audit_match.py` | 结构审计、小题分、填充率、答案题号对应 |
| `bishun_lib.py` / `gen_bishun.py` / `gen_bishun_solo.py` | 笔顺跟写练习（米字格分笔跟写） |

用法：`gen_exams2.py` → `gen_answers.py` → `render_any.py <docx>` → `audit_final.py`。

## 工作目录约定

- 新产物按主题进对应目录，不堆在根目录。
- 一次性脚本进 `工具/归档/过程脚本/`，可复用的进 `工具/脚本/`。
- 配图 URL 映射必须留在 `工具/归档/map/`，这是每张图的可追溯来源。
- 不进版本库：`_tmp/`、`_归档/`、Flutter 构建缓存、`*.apk`、`*.rar`、Word 临时文件（`~$*`）、`工具/`、`学生习题/`、`需求文档/`。
- Flutter 构建产物（`build/`、`.dart_tool/`、`android/.gradle/`）随时可删，需要时重跑构建即可。

## 已知遗留问题

1. **二上/二下 384 条没有逐条配图**（最高优先级，体验差距最大）
2. **CI 门禁改过但未确认 GitHub 上真实跑通**——本地门禁全绿，远端那次运行结果没看到
3. 三到六年级 768 张图为 800×800，统一压到 512 约省 18–20MB
4. `Image.asset` 未设 `cacheWidth`，512 图每张解码约 1MB（列表懒加载，暂不影响）
5. 一年级 354 张图只抽检 6 张，其余未逐张视觉复核
6. APK 仍是 debug key 签名，自用可装，分享给别人前要建正式 keystore
7. 单词无慢速版（设计如此，只有句子做慢速）

## 关键约定

- 教材原文一个字不改：`a teddy bear a teddy bear` 这类 chant、标题式无句号句，都是原文
- 配图禁止出现图内文字、数字、成人手
- 角色跨图一致：Mia 粉裙双辫、Tiantian 齐耳短发浅黄衣、Jinjin 扎两个小辫粉裙、Leo 黄衣棕发、Lele 棕短发蓝衣、Meimei 双马尾红衣、爸爸蓝毛衣、妈妈粉衣围裙、爷爷白发圆框眼镜、奶奶卷发眼镜紫开衫
- 英式口音；`color` 按教材用美式拼写
- 知识卡映射 key 是 `b{bookId}_{itemId}`（`Unit.progressKey()`），调用必须带册号前缀，否则永远查不到——已有回归测试锁住

## 隐私

- 纯离线运行，不收集任何数据
- 录音仅存本机 App 私有目录，不上传
- 无账号、无广告、无追踪

## 最近提交

```
9f23fda audio: 一年级上下册 61 个单词音统一为 Libby 24k 单声道
836fa42 fix: 知识卡因 id 前缀不匹配永不弹出 + CI 慢速阈值假红 + 重做 U4_S33 配图
92d4ff4 feat(book2): 一年级下册全册场景配图完成（219 张）
6aebb43 feat: 一年级上下册全量场景配图 + 全部句子换 Libby 语音
```
