"""Original game models, generated in Blender 4.3. Run with blender -b --python.
GLB contains reusable named models; textures embedded. No external assets.
"""
import bpy, math, random, struct, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/nasser_stahl.glb'
random.seed(7204)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def coord(v): return Vector((v[0],-v[2],v[1]))
def group(name):
 o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); return o

def material(name,color,rough=.6,metal=0,pattern=None):
 m=bpy.data.materials.new(name); m.use_nodes=True
 b=m.node_tree.nodes.get('Principled BSDF'); b.inputs['Base Color'].default_value=(*color,1); b.inputs['Roughness'].default_value=rough; b.inputs['Metallic'].default_value=metal
 if pattern:
  size=256; img=bpy.data.images.new(name+'_texture',width=size,height=size,alpha=True)
  pixels=[]; rnd=random.Random(59)
  for y in range(size):
   for x in range(size):
    n=rnd.uniform(-.06,.06); u=x/size; v=y/size
    alpha=1.0
    if pattern=='wood':
     n=rnd.uniform(-.008,.008)+.035*math.sin(x*.18+math.sin(y*.012))+.009*math.sin(x*.6+y*.008)
     for kx,ky in [(70,85),(185,180)]:
      r=math.sqrt(((x-kx)*.7)**2+((y-ky)*.16)**2)
      if r<15: n-=.07*(1+math.cos(r*1.5))*(1-r/15)
    elif pattern=='cloth': n=rnd.uniform(-.015,.015)+.009*math.sin(x*2)*math.sin(y*2)
    elif pattern=='bark': n+=.09*math.sin(x*.27+math.sin(y*.08))-.04*abs(math.sin(x*.8+y*.03))
    elif pattern=='metal': n+=.025*math.sin(y*.72)
    elif pattern=='roof':
     if y%32<2 or (x+((y//32)%2)*16)%32<2:n-=.14
     n+=.04*math.sin(x*.1+y*.22)
    elif pattern=='needles':
     # tapered bough silhouette with individual serrated needle edges.
     width=(1-v)*.47+.025
     edge=abs(u-.5)
     width*=.72+.28*abs(math.sin(v*93))
     alpha=1 if edge<width and v>.025 and v<.98 else 0
     n+=.09*(1-v)+.025*math.sin(x*.4+y*.8)
    pixels.extend([max(0,min(1,c+n)) for c in color]+[alpha])
  img.pixels=pixels; img.pack()
  tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img
  m.node_tree.links.new(tex.outputs['Color'],b.inputs['Base Color'])
  if pattern=='needles':
   m.node_tree.links.new(tex.outputs['Alpha'],b.inputs['Alpha']); m.surface_render_method='DITHERED'
 return m
WOOD=material('Aged oak',(.30,.20,.12),.65,pattern='wood')
BARK=material('Wet bark',(.22,.18,.13),.82,pattern='bark')
STEEL=material('Blued steel',(.17,.19,.21),.34,.65,'metal')
ROOF=material('Weathered roof tiles',(.29,.30,.31),.62,0,'roof')
LEAF=material('Pine needles',(.14,.25,.17),.88,0,'needles')
SKIN=material('Skin',(.49,.37,.27),.8)
CLOTH=material('Field wool',(.26,.31,.24),.96,pattern='cloth')
LEATHER=material('Leather',(.15,.10,.07),.75)
DARK=material('Soot',(.055,.065,.07),.82)
GLASS=material('Window glass',(.22,.37,.41),.16,.22)

def finish(o,parent,mat):
 o.parent=parent; o.data.materials.append(mat)
 if o.type=='MESH' and len(o.data.polygons):
  bpy.context.view_layer.objects.active=o; o.select_set(True)
  if not o.data.uv_layers:
   bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(island_margin=.025); bpy.ops.object.mode_set(mode='OBJECT')
  o.select_set(False)
 return o

def box(parent,pos,size,mat,bevel=0,name='detail'):
 bpy.ops.mesh.primitive_cube_add(size=1,location=coord(pos)); o=bpy.context.object; o.name=name
 o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Soft edges','BEVEL'); mod.width=bevel; mod.segments=2
  bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,parent,mat)

def cyl(parent,a,b,radius,mat,vertices=10,radius_top=None,name='round_detail'):
 aa,bb=coord(a),coord(b); vector=bb-aa
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius if radius_top is None else radius_top,depth=vector.length,location=(aa+bb)/2)
 o=bpy.context.object; o.name=name; o.rotation_euler=vector.to_track_quat('Z','Y').to_euler()
 for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
 return finish(o,parent,mat)

def ellipsoid(parent,pos,size,mat,name='rounded'):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=coord(pos)); o=bpy.context.object; o.name=name
 o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return finish(o,parent,mat)

def mesh(parent,name,vertices,faces,mat,uvs=None):
 data=bpy.data.meshes.new(name); data.from_pydata([coord(v) for v in vertices],[],faces); data.update()
 o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
 if uvs:
  uv=data.uv_layers.new()
  for face in data.polygons:
   for j,idx in enumerate(face.loop_indices):uv.data[idx].uv=uvs[j%len(uvs)]
 return finish(o,parent,mat)

# Six slightly irregular planks fill a destruction panel, with narrow seams.
g=group('WallPanel')
for i in range(6):
 x=(i-2.5)/6
 box(g,(x,0,0),(1/6-.005,3.2/3-.006,.2),WOOD,.008,'plank')
 for y in [-.40,.40]:
  for z in [-.102,.102]:cyl(g,(x,y,z),(x,y,z+(.006 if z>0 else -.006)),.013,STEEL,8,name='nail')
# Roof is origin-centered, pitched upward, with carved rafters and ridge caps.
g=group('HutRoof')
for side in [-1,1]:
 o=box(g,(side*1.65,.55,0),(3.48,.15,5.65),ROOF,.035,'roof_slope'); o.rotation_euler.y=side*.29
 for z in [-2.5,-1.25,0,1.25,2.5]:cyl(g,(0,1.05,z),(side*3.28,.08,z),.065,WOOD,6,name='rafter')
for z in [-2.5,2.5]:
 mesh(g,'gable',[(-3,-.1,z),(3,-.1,z),(0,1.03,z)],[(0,2,1) if z<0 else (0,1,2)],WOOD)
for z in range(12):cyl(g,(0,1.07,-2.8+z*.47),(0,1.07,-2.8+(z+1)*.47),.095,ROOF,10,name='ridge_cap')
# Window frame / lantern remain attached to the wall tile they decorate.
g=group('Window')
for x in [-.37,.37]:box(g,(x,0,0),(.045,.67,.06),WOOD,.008)
for y in [-.33,.33]:box(g,(0,y,0),(.77,.045,.06),WOOD,.008)
box(g,(0,0,0),(.025,.66,.05),WOOD,.004)
box(g,(0,0,0),(.73,.025,.05),WOOD,.004)
box(g,(0,0,-.022),(.68,.58,.018),GLASS,.003)
g=group('Lantern')
cyl(g,(0,-.13,0),(0,.13,0),.10,GLASS,8)
for y in [-.16,.16]:cyl(g,(0,y-.025,0),(0,y+.025,0),.13,STEEL,8)
for x,z in [(-.08,-.08),(.08,-.08),(-.08,.08),(.08,.08)]:cyl(g,(x,-.13,z),(x,.13,z),.008,STEEL,6)

for variant in range(2):
 g=group('Pine_'+('A' if variant==0 else 'B'))
 height=6.7+variant*.9
 cyl(g,(0,0,0),(.07,height,0),.24,BARK,10,.028,'trunk')
 for level in range(7):
  y=1.8+level*.66; width=(height-y)*.34
  for arm in range(5):
   a=arm*math.tau/5+level*.62+variant*.3
   direction=Vector((math.cos(a),0,math.sin(a)))
   end=direction*width
   cyl(g,(0,y,0),(end.x,y-.25,end.z),.036,BARK,6,.009,'branch')
   for offset in [-.23,.23]:
    mid=direction*width*.65
    lateral=Vector((-direction.z,0,direction.x))
    center=mid+lateral*offset
    # Three-dimensional tapered cards with alpha-cutout needle texture.
    for tilt in [0,math.pi/2]:
     across=lateral*math.cos(tilt)+Vector((0,1,0))*math.sin(tilt)
     tail=direction*width*.08; tip=direction*width*1.10
     verts=[]
     for along,sign in [(tail,-1),(tail,1),(tip,1),(tip,-1)]:
      p=along+across*width*.30*sign+lateral*offset
      verts.append((p.x,y+p.y-.10-((along.length/max(width,.1))*.30),p.z))
     mesh(g,'needle_bough',verts,[(0,1,2,3)],LEAF,[(0,0),(1,0),(1,1),(0,1)])

# Rifle coordinates match first-person view: muzzle towards Godot -Z.
g=group('Rifle')
# Organic stock profile instead of a rectangular block.
verts=[]
profile=[(-.15,.23),(.03,.23),(.10,.05),(.08,-.16),(.025,-.38),(-.04,-.42),(-.085,-.20),(-.10,.02)]
# profile coordinates are (height, z), thickness along x.
for x in [-.035,.035]:
 for y,z in profile:verts.append((x,y,z))
n=len(profile); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh(g,'carved_stock',verts,faces,WOOD)
box(g,(0,-.012,-.55),(.065,.075,.45),WOOD,.014,'forestock')
box(g,(0,.04,-.40),(.07,.055,.27),STEEL,.009,'receiver')
cyl(g,(0,.055,-.50),(0,.055,-1.03),.017,STEEL,12,name='barrel')
cyl(g,(0,.065,-.34),(.065,.065,-.34),.009,STEEL,8,name='bolt_stem')
ellipsoid(g,(.07,.06,-.34),(.018,.018,.018),STEEL,'bolt_handle')
for z in [-.9,-.70]:box(g,(0,.025,z),(.08,.07,.025),STEEL,.004,'barrel_band')
box(g,(0,.09,-.87),(.021,.035,.022),STEEL,.003,'front_sight')
box(g,(0,.087,-.42),(.04,.02,.016),STEEL,.003,'rear_sight')
for x in [-.025,.025]:cyl(g,(x,-.07,-.27),(x,-.115,-.25),.006,STEEL,6,name='trigger_guard')
cyl(g,(-.025,-.115,-.25),(.025,-.115,-.25),.006,STEEL,6,name='trigger_guard')

# Jagged, tapered original wood splinter geometry.
g=group('Splinter')
mesh(g,'broken_wood',[(-.5,-.5,-.35),(.5,-.5,-.35),(.4,-.5,.35),(-.45,-.5,.35),(-.3,.5,-.2),(.12,.32,-.27),(.27,.47,.15),(-.2,.2,.27)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],WOOD)
g=group('MetalShard')
mesh(g,'bent_metal',[(-.5,0,-.5),(.5,0,-.5),(.4,.16,.5),(-.5,.32,.4),(-.5,-.1,-.5),(.5,-.1,-.5),(.4,.06,.5),(-.5,.22,.4)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],STEEL)
g=group('Crate')
for side in [-1,1]:
 for i in range(5):
  box(g,(side*.57,0,(i-2)*.23),(.055,.93,.225),WOOD,.01)
  box(g,((i-2)*.23,0,side*.57),(.225,.93,.055),WOOD,.01)
for i in range(5):box(g,((i-2)*.23,.48,0),(.225,.07,1.17),WOOD,.01)
for x in [-.43,.43]:
 for z in [-.59,.59]:box(g,(x,0,z),(.065,1.01,.035),STEEL,.006)

# Original generic soldier, separate limb pivots for a simple walk animation.
g=group('Soldier')
ellipsoid(g,(0,1.02,0),(.24,.35,.16),CLOTH,'jacket')
box(g,(0,.86,0),(.43,.06,.32),LEATHER,.01,'belt')
ellipsoid(g,(0,1.52,0),(.12,.15,.12),SKIN,'head')
ellipsoid(g,(0,1.64,.015),(.155,.09,.16),STEEL,'helmet')
box(g,(0,1.55,-.108),(.12,.025,.025),SKIN,.005,'brow')
box(g,(0,1.49,-.125),(.032,.06,.045),SKIN,.01,'nose')
for x in [-.045,.045]:ellipsoid(g,(x,1.535,-.118),(.01,.008,.008),DARK,'eye')
box(g,(0,1.12,.20),(.33,.37,.18),LEATHER,.035,'backpack')
for side in [-1,1]:
 leg=group('LegLeft' if side<0 else 'LegRight'); leg.parent=g; leg.location=coord((side*.12,.8,0))
 # Children coordinates are relative to each leg pivot.
 cyl(leg,(0,0,0),(0,-.39,0),.10,CLOTH,10,.075,'trouser')
 cyl(leg,(0,-.39,0),(0,-.68,0),.078,LEATHER,10,.07,'gaiter')
 box(leg,(0,-.71,-.075),(.17,.14,.29),LEATHER,.04,'boot')
 cyl(g,(side*.23,1.29,0),(side*.32,1.03,-.10),.082,CLOTH,10,.068,'upper_arm')
 cyl(g,(side*.32,1.03,-.10),(side*.16,1.14,-.32),.062,CLOTH,10,.045,'forearm')
 ellipsoid(g,(side*.16,1.14,-.32),(.052,.055,.065),SKIN,'hand')
 cyl(g,(.14,1.12,-.20),(.14,1.12,-.8),.014,STEEL,10,name='rifle_barrel')
 box(g,(.14,1.08,-.38),(.06,.08,.42),WOOD,.014,'rifle_stock')

# Train silhouettes with round boilers, steel wheels, underframes and plank wagons.
g=group('Locomotive')
box(g,(0,.65,0),(2.1,.22,4.7),STEEL,.03,'underframe')
cyl(g,(0,1.65,-2),(0,1.65,.7),.70,DARK,16,name='boiler')
box(g,(0,1.55,1.45),(2.1,1.65,1.6),STEEL,.08,'cab')
box(g,(0,2.46,1.45),(2.27,.13,1.85),DARK,.04,'cab_roof')
for side in [-1,1]:box(g,(side*1.065,1.95,1.37),(.018,.55,.65),GLASS,.015,'cab_window')
cyl(g,(0,2.1,-1.5),(0,3.15,-1.5),.22,STEEL,12,.29,'chimney')
cyl(g,(0,2.13,-.20),(0,2.55,-.20),.21,STEEL,12,.10,'steam_dome')
for z in [-1.6,-.45,.7,1.7]:
 for side in [-1,1]:
  cyl(g,(side*.93,.43,z),(side*1.11,.43,z),.43,STEEL,12,name='wheel')
for side in [-1,1]:cyl(g,(side*1.13,.43,-1.6),(side*1.13,.43,.7),.045,STEEL,8,name='connecting_rod')
g=group('Wagon')
box(g,(0,.6,0),(2.1,.2,4.7),STEEL,.025,'frame')
for side in [-1,1]:
 for y in range(6):box(g,(side*1.02,.84+y*.24,0),(.075,.225,4.6),WOOD,.01,'plank_wall')
 for z in [-2,-.7,.7,2]:box(g,(side*1.07,1.43,z),(.09,1.5,.10),STEEL,.01,'upright')
 for z in [-1.6,1.6]:cyl(g,(side*.93,.38,z),(side*1.12,.38,z),.36,STEEL,12,name='wheel')
for z in [-2.28,2.28]:box(g,(0,1.45,z),(2,1.4,.075),WOOD,.025,'end_panel')
box(g,(0,2.25,0),(2.23,.15,4.85),ROOF,.055,'wagon_roof')

# Merge geometry per model (and per animated limb) to reduce draw calls.
for parent in [o for o in bpy.data.objects if o.type=='EMPTY']:
 meshes=[o for o in parent.children if o.type=='MESH']
 if len(meshes)>1:
  bpy.ops.object.select_all(action='DESELECT')
  for o in meshes:o.select_set(True)
  bpy.context.view_layer.objects.active=meshes[0]
  bpy.ops.object.join(); bpy.context.object.name=parent.name+'_Geometry'

# Export compact GLB. Foliage uses alpha MASK, never full-screen alpha blending.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_yup=True,export_apply=True,export_animations=False)
data=OUT.read_bytes(); chunks=[]; offset=12
while offset<len(data):
 length,kind=struct.unpack_from('<II',data,offset); payload=data[offset+8:offset+8+length]; offset+=8+length
 if kind==0x4e4f534a:
  document=json.loads(payload)
  for mat in document.get('materials',[]):
   if mat.get('name')=='Pine needles':mat['alphaMode']='MASK';mat['alphaCutoff']=.5;mat['doubleSided']=True
  payload=json.dumps(document,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
 chunks.append(struct.pack('<II',len(payload),kind)+payload)
body=b''.join(chunks); OUT.write_bytes(struct.pack('<III',0x46546c67,2,12+len(body))+body)
print('MODEL EXPORT:',OUT,OUT.stat().st_size,'bytes')
