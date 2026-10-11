"""Independently check all PNG CRCs and exact native RGBA bytes."""
import argparse, hashlib, json, struct, zlib
from pathlib import Path

def sha(raw): return hashlib.sha256(raw).hexdigest()
def decode(path):
    raw=path.read_bytes()
    assert len(raw)<20*1024**2 and raw[:8]==b"\x89PNG\r\n\x1a\n"
    offset=8; compressed=[]; width=height=None; types=[]
    while offset<len(raw):
        size=struct.unpack_from('>I',raw,offset)[0]
        kind=raw[offset+4:offset+8];data=raw[offset+8:offset+8+size]
        assert len(data)==size and offset+12+size<=len(raw)
        crc=struct.unpack_from('>I',raw,offset+8+size)[0]
        assert (zlib.crc32(kind+data)&0xffffffff)==crc
        types.append(kind.decode('ascii'))
        if kind==b'IHDR':
            width,height,depth,color,compression,filtering,interlace=struct.unpack('>IIBBBBB',data)
            assert 0<width<=4096 and 0<height<=4096
            assert (depth,color,compression,filtering,interlace)==(8,6,0,0,0)
        elif kind==b'IDAT': compressed.append(data)
        elif kind==b'IEND': assert not data
        offset+=12+size
    assert types[0]=='IHDR' and types[-1]=='IEND' and offset==len(raw)
    encoded=zlib.decompress(b''.join(compressed))
    stride=width*4
    assert len(encoded)==height*(stride+1)
    pixels=bytearray(); previous=bytearray(stride)
    for y in range(height):
        flag=encoded[y*(stride+1)]; row=bytearray(encoded[y*(stride+1)+1:(y+1)*(stride+1)])
        assert flag<=4
        for x in range(stride):
            left=row[x-4] if x>=4 else 0; above=previous[x]; diagonal=previous[x-4] if x>=4 else 0
            if flag==0: value=0
            elif flag==1: value=left
            elif flag==2: value=above
            elif flag==3: value=(left+above)//2
            else:
                pred=left+above-diagonal
                a,b,c=abs(pred-left),abs(pred-above),abs(pred-diagonal)
                value=left if a<=b and a<=c else above if b<=c else diagonal
            row[x]=(row[x]+value)&255
        pixels.extend(row); previous=row
    return {'bytes':len(raw),'png_sha256':sha(raw),'rgba_sha256':sha(pixels),'all_crcs_checked':True,'dimensions':[width,height]}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('capture',type=Path);args=parser.parse_args()
    native=json.loads((args.capture/'ui-review.json').read_text());assert native['passed']
    rows=[]
    for view in native['views']:
        row=decode(args.capture/view['file']);row['file']=view['file']
        row['passed']=row['png_sha256']==view['png_sha256'] and row['rgba_sha256']==view['rgba_sha256'] and row['dimensions']==view['texture_size']
        assert row['passed'];rows.append(row)
    assert len(rows)==48
    output={'schema':'mush-independent-ui-rgba-check/1','passed':True,'method':'stdlib full PNG chunk CRC/inflate/five-filter/Paeth RGBA reconstruction, independent of Godot','ui_report_sha256':sha((args.capture/'ui-review.json').read_bytes()),'views':rows,'human_usability_approved':False}
    target=args.capture/'png-check.json';assert not target.exists();target.write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({'passed':True,'views':len(rows),'report':str(target)}))
if __name__=='__main__':main()
