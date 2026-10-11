"""Original offline synthesis: soft ambient bed, restrained regional music and cues.
No downloaded samples or model outputs. Source is the reproducible score.
"""
from pathlib import Path
import wave, math, random, array
RATE=22050
ROOT=Path(__file__).parent

def save(name,data,loop=False):
    peak=max(abs(v) for v in data) or 1
    gain=min(1,.85/peak)
    pcm=array.array('h',(int(max(-1,min(1,v*gain))*32767) for v in data))
    with wave.open(str(ROOT/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
    if loop:
        (ROOT/(name+'.import')).write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\nloop_mode=1\nloop_begin=0\nloop_end=-1\n')

def tone(freq,t):
    return math.sin(2*math.pi*freq*t)+.17*math.sin(2*math.pi*freq*2*t)+.045*math.sin(2*math.pi*freq*3*t)
# A spare pentatonic phrase, A D E F# A, over four gentle dyads. 32s seamless phrase.
duration=32
score=[(0,220),(4,293.6648),(8,329.6276),(12,369.9944),(16,440),(20,369.9944),(24,329.6276),(28,293.6648)]
data=[]
for n in range(RATE*duration):
    t=n/RATE; v=0
    for start,freq in score:
        age=(t-start)%duration
        if age<7:
            env=(1-math.exp(-age*2))*math.exp(-age*.65)
            v+=.075*env*tone(freq,age)
            v+=.024*env*tone(freq/2,age)
    data.append(v)
save('clearing-music.wav',data,True)
# Smooth filtered wind with distant insect and bird phrases.
rng=random.Random(7104); duration=24;data=[];smooth=0
for n in range(RATE*duration):
    t=n/RATE
    smooth=smooth*.995+rng.uniform(-1,1)*.005
    wind=.20*smooth*(.65+.35*math.sin(2*math.pi*t/duration))
    chirp=0
    for at in [2,9,16]:
        age=t-at
        if 0<age<.7:
            env=math.sin(math.pi*age/.7)**2
            chirp+=.017*env*math.sin(2*math.pi*(1700*age+200*math.sin(age*15)))
    data.append(wind+chirp)
# fade boundary, retain silence-free ambience at join
for n in range(1100):
    data[n]*=n/1100;data[-1-n]*=n/1100
save('forest-ambience.wav',data,True)
for name,duration,freq in [('door',.55,110),('growth',1.4,440),('glow',.35,660),('footstep',.12,75)]:
    data=[]
    for n in range(int(RATE*duration)):
        t=n/RATE
        env=math.sin(math.pi*t/duration)**2*math.exp(-t*2)
        value=.12*env*tone(freq,t)
        if name=='growth':value+=.09*env*tone(freq*1.5,t)
        if name in ['footstep','door']:value+=.045*env*rng.uniform(-1,1)
        data.append(value)
    save(name+'.wav',data)
