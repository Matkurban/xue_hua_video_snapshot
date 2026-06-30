# Video Cover Extraction

跨平台 Flutter 插件的领域：从视频中抽取非黑的封面候选帧，供调用方挑选或展示缩略图。

## Language

**封面候选帧** (Cover candidate frame):
从视频中采样得到、通过亮度过滤的单帧图像及其元数据（时间位置、亮度值）。
_Avoid_: 缩略图, thumbnail, 封面图

**视频来源** (VideoSource):
调用方提供的视频输入，分为网络地址、本地文件、Flutter asset 三种形态。
_Avoid_: 媒体源, media source, 输入类型

**亮度过滤** (Brightness filter):
按可配置阈值丢弃接近纯黑的帧，只保留足够明亮的候选。
_Avoid_: 黑帧检测, dark frame detection

**采样策略** (Sampling policy):
在时间轴中间区间（跳过片头片尾各 5%）均匀选取若干候选位置，再按亮度排序截取。
_Avoid_: 抽帧策略, frame sampling logic

**封面抽取** (Cover extraction):
从解析后的视频来源中执行采样、亮度过滤、排序，产出封面候选帧列表的完整过程。
_Avoid_: 截图, snapshot, 封面生成

**封面抽取策略** (Cover extraction policy):
决定在时间轴哪些位置采样、如何衡量帧亮度、以及如何排序与截断候选的规则集合。
_Avoid_: 抽帧算法, extraction logic, 采样参数

**封面抽取失败** (Cover extraction failure):
无法探测视频时长或无法解码请求位置的帧，与「成功解码但无足够亮帧」不同。
_Avoid_: 错误, error, 异常
