# MuJoCo MJCF XML：六轴机械臂建模入门

## 状态与目标

- 创建日期：2026-08-24
- 状态：学习中
- 目标：能看懂 MJCF 的刚体树，并能从零搭出六轴机械臂模型。
- 本阶段完成条件：先让一个关节正确转动，再扩展到六个关节；不要一开始就导入全部网格。

## 1. 先建立一个直觉

MuJoCo 使用的 XML 格式通常叫 **MJCF**（MuJoCo XML model format）。它描述的不只是
机械臂外观，还描述物理仿真需要的内容：

1. 刚体怎样逐级连接；
2. 关节绕哪里、沿哪个轴运动；
3. 每个连杆的质量、质心和转动惯量；
4. 哪些形状参与显示，哪些形状参与碰撞；
5. 电机怎样施力，传感器读取什么量。

六轴串联机械臂最重要的结构不是“六个并列的关节”，而是一棵嵌套的刚体树：

```text
world
└── base（固定基座）
    └── link1 + joint1
        └── link2 + joint2
            └── link3 + joint3
                └── link4 + joint4
                    └── link5 + joint5
                        └── link6 + joint6
                            └── tool_site（末端坐标系）
```

父 `body` 运动时，其所有子 `body` 都会跟着运动。这就是串联机械臂必须逐层嵌套的原因。

## 2. XML 最基本的书写规则

```xml
<标签 属性名="属性值">
  <子标签/>
</标签>
```

- XML 只能有一个根标签；MJCF 的根标签是 `<mujoco>`。
- 属性值必须放在引号中，例如 `mass="2.5"`。
- 没有子内容的标签可以写成 `<joint .../>`。
- 注释写作 `<!-- 注释 -->`。
- 名称建议只使用字母、数字和下划线，例如 `joint1`、`link2_visual`。
- 向量通常以空格分隔，例如 `pos="0 0 0.25"`。

## 3. 常用顶层结构

一个机械臂模型通常按下面的顺序组织：

```xml
<mujoco model="arm6">
  <compiler .../>
  <option .../>
  <default>...</default>
  <asset>...</asset>
  <worldbody>...</worldbody>
  <contact>...</contact>
  <actuator>...</actuator>
  <sensor>...</sensor>
  <keyframe>...</keyframe>
</mujoco>
```

| 标签 | 用途 | 六轴机械臂中是否常用 |
|---|---|---|
| `<compiler>` | 角度单位、资源路径、自动限位 | 必须理解 |
| `<option>` | 步长、重力、积分器、求解器 | 必须理解 |
| `<default>` | 给同类元素设置默认属性，减少重复 | 建议使用 |
| `<asset>` | 注册 mesh、纹理、材质 | 使用 CAD 网格时需要 |
| `<worldbody>` | 定义环境、刚体、关节、几何体和 site | 核心 |
| `<contact>` | 明确排除或指定接触对 | 有自碰撞时常用 |
| `<actuator>` | 定义位置、速度或力矩执行器 | 核心 |
| `<sensor>` | 定义关节、力、位姿等传感器 | 建议使用 |
| `<keyframe>` | 保存 home 等初始姿态 | 建议使用 |

这不是要求每个文件都包含全部标签。先保留当前实验真正需要的部分。

## 4. 坐标、单位和位姿

建议在文件开头明确：

```xml
<compiler angle="radian" autolimits="true"/>
<option timestep="0.002" gravity="0 0 -9.81" integrator="implicitfast"/>
```

本笔记统一使用：

| 物理量 | 单位 |
|---|---|
| 长度 | m |
| 质量 | kg |
| 时间 | s |
| 角度 | rad（由 `angle="radian"` 明确指定） |
| 力 | N |
| 力矩 | N·m |

MuJoCo 使用右手坐标系。`pos="x y z"` 是位置。姿态常用以下任一种格式：

```xml
<body pos="0 0 0.2" euler="0 0 1.5708">
<body pos="0 0 0.2" quat="1 0 0 0">
```

- `body` 的 `pos` 和姿态是**相对于父 body 坐标系**的。
- `joint` 的 `pos` 和 `axis` 是在它所在 `body` 的局部坐标系中表达的。
- `quat` 的顺序是 `w x y z`。
- 同一个元素不要同时填写 `euler` 和 `quat`。

建机械臂时，最省心的约定是：把每个子 `body` 的原点放在该关节轴心，令关节
`pos="0 0 0"`。这样，`body pos` 就表示“上一个关节到下一个关节”的固定变换。

## 5. 一个可运行的最小关节模型

先读懂并运行这个模型。它只演示一种模式：固定基座、一个转动关节、一个位置执行器和
两个关节传感器。

```xml
<?xml version="1.0" encoding="utf-8"?>
<mujoco model="one_joint_arm">
  <compiler angle="radian" autolimits="true"/>
  <option timestep="0.002" gravity="0 0 -9.81"/>

  <worldbody>
    <geom name="floor" type="plane" size="2 2 0.1"/>

    <!-- 没有 joint 的 body 固定在世界上。 -->
    <body name="base" pos="0 0 0.1">
      <geom type="cylinder" size="0.12 0.1" mass="2"/>

      <body name="link1" pos="0 0 0.1">
        <joint name="joint1" type="hinge"
               pos="0 0 0" axis="0 1 0"
               range="-1.57 1.57" damping="0.2"/>
        <geom type="capsule" fromto="0 0 0 0 0 0.4"
              size="0.035" mass="0.8"/>
        <site name="tool_site" pos="0 0 0.4" size="0.015"/>
      </body>
    </body>
  </worldbody>

  <actuator>
    <position name="joint1_position" joint="joint1"
              kp="50" ctrlrange="-1.57 1.57"
              forcerange="-20 20"/>
  </actuator>

  <sensor>
    <jointpos name="joint1_position_sensor" joint="joint1"/>
    <jointvel name="joint1_velocity_sensor" joint="joint1"/>
  </sensor>
</mujoco>
```

请先能回答三个问题：

1. 删除 `joint1` 后，`link1` 为什么会固定？
2. 把 `axis="0 1 0"` 改成 `axis="0 0 1"`，运动方向发生什么变化？
3. `ctrlrange` 限制的是控制指令，`forcerange` 限制的是什么？

## 6. 六轴刚体树怎样展开

每增加一轴，都重复“子 body 内放 joint，再在其中嵌套下一个 body”的模式：

```xml
<body name="linkN" pos="上一关节到本关节的平移" quat="固定旋转">
  <joint name="jointN" type="hinge"
         pos="0 0 0" axis="本关节的局部轴"
         range="下限 上限"/>
  <inertial pos="质心位置" mass="质量" diaginertia="Ixx Iyy Izz"/>
  <geom name="linkN_visual" class="visual" type="mesh" mesh="linkN_mesh"/>
  <geom name="linkN_collision" class="collision" type="capsule" .../>

  <!-- 下一轴的 body 写在这里。 -->
</body>
```

注意：上面的 `N` 和 `...` 是讲解占位符，不能原样放进要加载的 XML。

六轴的结构信息应先填入下面这张表，再写 XML：

| 轴 | 父 body | `body pos/quat` | `joint axis`（局部） | `range` | 质量/质心/惯量 | 峰值力矩 |
|---|---|---|---|---|---|---|
| J1 | base | | | | | |
| J2 | link1 | | | | | |
| J3 | link2 | | | | | |
| J4 | link3 | | | | | |
| J5 | link4 | | | | | |
| J6 | link5 | | | | | |

这些数据分别应来自装配坐标、关节设计、CAD 质量属性和电机/减速器参数。不能仅凭机械臂
外观猜测。

## 7. 必须掌握的元素格式

### 7.1 `body`：一个刚体和一个局部坐标系

```xml
<body name="link2" pos="0 0 0.4" quat="1 0 0 0">
  ...
</body>
```

`body` 决定层级和固定变换。串联机构最常见的错误，是把 `link1` 到 `link6` 全都并列写在
`base` 下；那样它们不会形成正确的运动链。

### 7.2 `joint`：相对父 body 的自由度

```xml
<joint name="joint2" type="hinge"
       pos="0 0 0" axis="0 1 0"
       range="-2.0 2.0"
       damping="0.5" armature="0.01" frictionloss="0.05"/>
```

六轴旋转机械臂通常每轴使用一个 `type="hinge"`：

| 属性 | 含义 |
|---|---|
| `pos` | 关节轴经过的点，位于当前 body 局部系 |
| `axis` | 关节轴方向；MuJoCo 会将非零向量归一化 |
| `range` | 角度下限和上限 |
| `damping` | 与关节速度相关的被动力矩 |
| `armature` | 反映到关节侧的附加转动惯量 |
| `frictionloss` | 库仑摩擦损失的简化参数 |

不要用很大的 `damping` 掩盖惯量或控制器错误。`armature` 也不是“让仿真稳定”的任意旋钮，
它应尽量对应电机与减速器反射到关节侧的惯量。

### 7.3 `geom`：形状、碰撞和外观

原型阶段先用 `box`、`capsule`、`cylinder` 等简单几何体：

```xml
<geom type="capsule" fromto="0 0 0 0 0 0.35"
      size="0.04" mass="1.2"/>
```

- `fromto="x1 y1 z1 x2 y2 z2"` 很适合画连杆。
- 对 capsule，`size` 的第一个数是半径。
- 对 box，`size="x y z"` 表示三个方向的**半尺寸**。
- 对 cylinder，`size="radius half_length"`。

导入 CAD 后，建议显示网格和碰撞几何分开：

```xml
<asset>
  <!-- 如果 STL 以 mm 导出，缩放到 m。实际单位必须向 CAD 导出设置核实。 -->
  <mesh name="link1_mesh" file="meshes/link1.stl"
        scale="0.001 0.001 0.001"/>
</asset>

<default>
  <default class="visual">
    <geom contype="0" conaffinity="0" group="2" rgba="0.7 0.7 0.72 1"/>
  </default>
  <default class="collision">
    <geom group="3" rgba="0.2 0.7 0.2 0.25"/>
  </default>
</default>

<!-- 放在对应的 body 中。 -->
<geom name="link1_visual" class="visual" type="mesh" mesh="link1_mesh"/>
<geom name="link1_collision" class="collision" type="capsule"
      fromto="0 0 0 0 0 0.35" size="0.045"/>
```

视觉 mesh 只负责好看，简单碰撞体负责稳定、快速地算接触。若视觉 mesh 也参与碰撞，模型
常会变慢，并可能因三角网格细节出现意外接触。

### 7.4 `inertial`：质量、质心和转动惯量

```xml
<inertial pos="0 0 0.18"
          mass="1.2"
          diaginertia="0.012 0.011 0.003"/>
```

- `pos` 是质心在当前 body 局部系中的位置。
- `diaginertia` 是惯性主轴坐标系中的三个主惯量。
- 如果惯性主轴与 body 轴不一致，还要用 `quat` 指明惯性坐标系方向。

简单原型可通过带 `mass` 或 `density` 的 geom 推算惯性。换成真实机械臂时，优先从 CAD
导出每个独立连杆的质量属性并显式填写 `<inertial>`。检查三个主惯量都为正，且单位为
`kg·m²`；把 `kg·mm²` 直接当成 `kg·m²` 会造成百万倍错误。

### 7.5 `site`：没有质量的标记坐标系

```xml
<site name="tool_site" pos="0 0 0.12" quat="1 0 0 0"
      size="0.012" rgba="1 0 0 1"/>
```

`site` 常用于标记 TCP（工具中心点）、安装传感器、定义力/力矩测量位置。它不是新的刚体，
不会增加自由度。

### 7.6 `actuator`：控制输入怎样变成关节作用

先掌握两种：

```xml
<actuator>
  <!-- ctrl 是目标角度。 -->
  <position name="j1_servo" joint="joint1"
            kp="100" ctrlrange="-3.14 3.14" forcerange="-80 80"/>

  <!-- ctrl 经过 gear 后形成广义力；适合自己在外部写力矩控制器。 -->
  <motor name="j2_motor" joint="joint2"
         gear="1" ctrlrange="-60 60"/>
</actuator>
```

| 执行器 | `ctrl` 的直觉 | 适合场景 |
|---|---|---|
| `<position>` | 目标关节位置 | 快速验证机构、位置伺服 |
| `<motor>` | 经传动系数映射的控制输入 | 自己实现 PD、计算力矩或其他力矩控制 |

不要把 `<position>` 的 `ctrl` 当作力矩。还要同时考虑控制范围和输出力范围；否则控制器可能
要求机械系统不可能提供的力矩。

六个独立关节通常对应六个 actuator。它们的声明顺序也决定控制向量 `ctrl` 的顺序，因此
建议始终按 `joint1` 到 `joint6` 排列。

### 7.7 `sensor`：记录验证所需的数据

```xml
<sensor>
  <jointpos name="j1_q" joint="joint1"/>
  <jointvel name="j1_dq" joint="joint1"/>
  <actuatorfrc name="j1_actuator_force" actuator="j1_servo"/>
  <framepos name="tcp_position" objtype="site" objname="tool_site"/>
  <framequat name="tcp_orientation" objtype="site" objname="tool_site"/>
</sensor>
```

传感器数据会按 XML 中的声明顺序打包到 `sensordata`。读取程序不要凭感觉写下标；应通过
传感器名称查询地址和维度。

### 7.8 `keyframe`：保存 home 姿态

当模型恰好有 6 个 hinge 自由度和 6 个 actuator 时，可以写：

```xml
<keyframe>
  <key name="home"
       qpos="0 -1.5708 1.5708 0 0 0"
       ctrl="0 -1.5708 1.5708 0 0 0"/>
</keyframe>
```

`qpos` 数量必须与模型的位置变量数量一致，`ctrl` 数量必须与执行器数量一致。以后增加夹爪
或移动底座时，这两个向量的长度也要重新检查。

## 8. 用 `default` 减少六次重复

```xml
<default>
  <default class="arm_joint">
    <joint type="hinge" damping="0.3" armature="0.01"/>
  </default>
</default>

<joint name="joint1" class="arm_joint" axis="0 0 1" range="-3.14 3.14"/>
```

`default` 适合放共同的初始参数。每个关节的轴、范围、惯量和力矩限制往往不同，不要为了
少写几行而把真实差异抹掉。

模型变大后还可以用 `<include file="..."/>` 拆分文件，例如把资产、机械臂和场景分别放入
文件。初学阶段先保持单文件，便于看清层级。

## 9. 推荐的建模顺序

### 阶段 A：只验证运动学结构

1. 用 capsule、box 和 cylinder 搭 J1、J2。
2. 暂时设 `gravity="0 0 0"`，逐个给很小的关节控制量。
3. 检查关节轴、正方向、关节原点和父子关系。
4. 扩展到 J6，并在末端添加 `tool_site`。

完成标志：每次只动一个关节时，下游连杆一起动，上游连杆不动。

### 阶段 B：加入真实质量属性

1. 从 CAD 获取每个连杆的质量、质心和惯量。
2. 恢复重力。
3. 检查静止姿态下是否出现异常加速度或巨大控制力。

完成标志：单位、质心方向和惯量数量级均有来源，模型不会无故“爆炸”。

### 阶段 C：加入驱动和限制

1. 填写六个关节的运动范围。
2. 根据减速器输出能力填写每轴力矩范围。
3. 先用较温和的位置增益，再逐步整定。

完成标志：到达限位时不穿越，控制输出不超过设定能力。

### 阶段 D：加入碰撞、传感器和控制器

1. 用简单形状覆盖主要连杆体积。
2. 检查地面碰撞、自碰撞和相邻连杆接触。
3. 记录六轴位置、速度、执行器输出以及 TCP 位姿。
4. 再接入轨迹控制程序。

## 10. 每次加载模型都要检查什么

| 检查项 | 简单验证方法 | 常见错误信号 |
|---|---|---|
| 尺寸单位 | 看基座和连杆是否符合米制数量级 | 模型巨大或小到看不见 |
| 父子层级 | 单独移动一个关节 | 下游连杆不跟随 |
| 关节原点 | 小角度正反转 | 连杆绕奇怪的位置公转 |
| 关节轴 | 显示局部坐标轴并单轴运动 | 转动平面错误或方向反了 |
| 质量/质心 | 开启重力、观察静止和下落趋势 | 加速度异常、控制力极大 |
| 惯量 | 对关节施加小力矩 | 响应快得不合理或数值发散 |
| 碰撞体 | 显示碰撞组、慢速接近 | 未接触就弹开或互相穿透 |
| 限位 | 发送略超范围的目标 | 穿过机械限位 |
| 控制顺序 | 每次只给一个 `ctrl` 非零值 | 控制了错误关节 |
| TCP | 比较 home 姿态下的手算位置 | 末端位置固定偏移或轴向错误 |

## 11. 仿真稳定性验收

白板要求“仿真步长变化后结果保持稳定”。可以这样留下证据：

1. 固定同一模型、控制器、初始状态和目标轨迹。
2. 分别使用 `timestep="0.002"`、`0.001` 和 `0.0005`。
3. 保存六轴 `q`、`dq`、控制输出和 TCP 轨迹，而不只保存截图。
4. 比较最大跟踪误差、RMS 跟踪误差和控制峰值。
5. 先暂定相邻两种步长的 RMS 结果差异不超过 5%；之后可根据项目精度重新定阈值。

若减小步长后结果明显改变，优先检查惯量单位、碰撞穿透、过高控制增益、过硬接触和关节
阻尼，而不是直接增加求解器迭代次数。

## 12. 常见错误速查

| 现象 | 可能原因 | 第一个检查动作 |
|---|---|---|
| XML 无法加载 | 标签没闭合、属性拼错、名称重复 | 从报错行检查成对标签和属性 |
| 六个连杆各自转动 | body 没有逐层嵌套 | 画出实际 body 树 |
| 旋转中心错误 | `body pos` 或 `joint pos` 错 | 把 body 原点移到关节轴心 |
| 旋转方向错误 | `axis` 在错误坐标系中填写 | 在当前 body 局部系画出轴向 |
| mesh 尺寸错误 | mm/m 混用 | 检查 mesh `scale` 和 CAD 导出单位 |
| 一开始就猛烈抖动 | 初始穿透、增益过高或惯量错误 | 关闭碰撞并降低增益做隔离 |
| 关节到不了目标 | 输出力矩受限或重力负载过大 | 同时记录误差和 actuator force |
| 模型加载但没有控制 | 只定义了 joint，没有 actuator | 检查 actuator 是否引用正确 joint |

## 13. 你的第一轮练习

一次只做下面三步：

1. 打开本目录的 `learn_joint.xml`，先指出 `base → link1 → link2` 的父子关系。
2. 为 `shoulder` 和 `elbow` 分别补上 `range`，并用纸画出它们当前 `axis="0 1 0"` 的正方向。
3. 自己补一个 `<actuator>`，先只控制 `shoulder`；加载成功后再增加 `elbow`。

这一轮的验收不是“六轴模型已经完成”，而是你能解释 `body`、`joint` 和 `actuator` 三者
分别负责什么，并能让两个关节按预期单独运动。

## 14. 资料来源

以下官方资料已于 2026-08-24 核验：

- MuJoCo Documentation, **XML Reference**：
  <https://mujoco.readthedocs.io/en/stable/XMLreference.html>
  （查每个 MJCF 标签和属性的准确含义。）
- MuJoCo Documentation, **Modeling**：
  <https://mujoco.readthedocs.io/en/stable/modeling.html>
  （理解模型编译、坐标系、惯性和建模建议。）

官方 XML Reference 是属性是否存在、单位和默认值的最终依据。版本升级后若模型出现解析
错误，应先用当前安装版本对应的文档核对，而不是依赖旧教程。

## 下一步

- [ ] 给 `learn_joint.xml` 的两个关节补限位。
- [ ] 给两个关节补位置执行器，并逐轴测试。
- [ ] 给末端增加 `site`，记录它在 home 姿态下的位置。
- [ ] 完成上面的六轴结构参数表，再开始扩展 J3 到 J6。
