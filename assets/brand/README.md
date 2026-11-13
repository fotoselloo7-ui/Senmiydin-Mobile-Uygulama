# SenMiydin? marka kaynağı

Bu işaret mevcut onaylı arayüzdeki geçici semboldür; final logo değildir. Yeni bir logo üretilmedi.

Merkezi kaynak: mark.svg. Flutter bu kaynağı doğrudan okur. Platform ve web çıktıları tool/export_brand_icons.py ile üretilir. Final sembol geldiğinde bu SVG'yi aynı viewBox içinde değiştirip export komutunu çalıştır. Wordmark metni mevcut tipografiyle SenMiydin? olarak kalır.

Kaynak SVG kare bir viewBox kullanmalı; arka plan içermemeli. Export aracı Android adaptive icon, Android splash, iOS ikon / splash, web favicon ve OG görselini güvenli kenar boşluğu ile üretir.

Python bağımlılıkları: Pillow ve resvg-py. Yerel kurulum ve komut docs/DEPLOYMENT.md içindedir. Üretilen dosyaları kaynakla birlikte dağıt.
