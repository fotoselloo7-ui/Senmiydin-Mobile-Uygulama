import urllib.request, pathlib, concurrent.futures
root=pathlib.Path.cwd()
files={
'assets/fonts/NunitoSans.ttf':'https://raw.githubusercontent.com/google/fonts/main/ofl/nunitosans/NunitoSans%5BYTLC%2Copsz%2Cwdth%2Cwght%5D.ttf',
'assets/fonts/OFL.txt':'https://raw.githubusercontent.com/google/fonts/main/ofl/nunitosans/OFL.txt',
'assets/images/coast.jpg':'https://images.unsplash.com/photo-1519451241324-20b4ea2c4220?w=1200&q=85&fit=crop',
'assets/images/coffee.jpg':'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=900&q=85&fit=crop',
'assets/images/sunset.jpg':'https://images.unsplash.com/photo-1472120435266-53107fd0c44a?w=1000&q=85&fit=crop',
'assets/images/journey.jpg':'https://images.unsplash.com/photo-1474487548417-781cb71495f3?w=1000&q=85&fit=crop',
}
for i,(sex,num) in enumerate([('men',32),('women',44),('men',11),('women',68),('men',46),('women',49),('men',75),('women',65),('men',22),('women',25),('men',52),('women',32)]):
 files[f'assets/images/user_{i}.jpg']=f'https://randomuser.me/api/portraits/{sex}/{num}.jpg'
def fetch(item):
 p,url=item
 req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
 data=urllib.request.urlopen(req,timeout=35).read()
 (root/p).write_bytes(data)
 return f'{p}: {len(data)} bytes'
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for result in pool.map(fetch,files.items()): print(result)
