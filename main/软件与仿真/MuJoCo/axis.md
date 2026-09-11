## Mujoco坐标系
**默认右手坐标系**

world 坐标系是全局固定参考系。worldbody 里的物体位置相对 world：
```
        <worldbody>
            <body name="table" pos="1 0 0.75">
```