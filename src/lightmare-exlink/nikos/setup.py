#coding:utf-8
from setuptools import setup, find_packages
from codecs import open
from os import path

__version__ = '0.1.0'

base_path = path.abspath(path.dirname(__file__))
with open(path.join(base_path, 'requirements.txt'), encoding='utf-8') as f: all_reqs = f.read().split('\n')
install_requires = [one.strip() for one in all_reqs]

setup(
    name='nikos',
    version=__version__,
    description='the python version of exlink mode',
    url='https://gitlab.ctbiyi.com/Frampt/lightmare-exlink',
    download_url=f'https://gitlab.ctbiyi.com/Frampt/lightmare-exlink/-/tree/master/nikos/dist/nikos-{__version__}.tar.gz',
    license='MIT',
    author_email='matthrewchains@gmail.com',
    author='Matt',
    packages=find_packages(),           # 查询当前目录下有哪些包
    include_package_data=True,          # 在MANIFEST.in文件指定的包目录中自动包含找到的所有数据文件
    install_requires=install_requires,  # 当前模块依赖哪些包，安装模块时自动安装依赖包
    setup_requires=[],                  # 运行setup.py本身要依赖的包 eg. ['numpy>=1.10', 'scipy>=0.17']
    dependency_links=[],                # 用于安装setup_requires的软件包,指定依赖包的下载地址 eg. ["http://xxxxxxx.com/xxxxx-1.0.tar.gz"]
)
