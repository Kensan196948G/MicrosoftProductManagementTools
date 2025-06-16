#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
提供されたユーザーデータテキストから綺麗なCSVファイルを生成するPythonスクリプト
"""

import csv
import sys
from datetime import datetime

def main():
    # 提供されたユーザーデータを解析
    user_data_text = """荒木 厚史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 奨 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤　慎太郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小野 昭司 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鬼丸 覚 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 新次 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大谷　伸介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小笠原 秀光 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 野村 信二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中山 新吾 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中野 慎一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長岡 伸一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 進藤　愁也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長江 進 052 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小島 栄 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川村　慎二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上村 爽空 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 神川 里美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 泉 誠司郎 046 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岩崎　志門 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 茂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 池田 紳之介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 堀　聡 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 東 正真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 服部 俊朗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 今　真吾 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 後野 秀一郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 塩野谷　咲希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口　純代 027 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岩崎 泰治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石原 敏彦 059 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 稲毛 健 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市岡 匠 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 羽矢崎 友香 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 服部 恒夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 濱田 高明 053 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福田 猛 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 藤原 鼓 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 江原 知希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 赤坂 聡哉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 染川 紗杏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿知良 巧 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 多田 翔伍 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 栗原 竣介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石原 慎太郎 041 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 藤原 伸治 078 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加藤 里美 020 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 聡 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉江 真一 087 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 津田 颯太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 坪井 俊太朗 009 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 友清 真一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 玉木 茂樹 077 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 尾方 柊真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 門田　利治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福田 総一郎 048 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木　崚太 103 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 武村 奈穂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 高田 七奈 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 砂子 範行 076 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 菅波 則克 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大崎 経生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 直美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 永江 愛美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 貴志 直稀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 井上 渚沙 108 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 服部　登 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 畑岡 直樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 寺本 信人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 有田　尚史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡辺 光男 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤　淳 054 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡邉　真澄 024 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口　愛美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み ザーニ トェイ 073 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長谷川　茉侑 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 足立 雅樹 044 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉冨　三矢 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柳沢 真穂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山本 美由貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 桃子 014 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 富 靖閔 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 登坂 成葉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉谷 直樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山﨑　龍馬 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田島 陸豊 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木 龍一 006 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 下田 伶央斗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大久保 澪弥 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小笠原 涼子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大日方 亮汰 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 野口 藍 031 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西田 竜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 新倉 怜於 005 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中畑 亮一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡邉 なおみ 015 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松尾 蓮 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小堀 諒士 075 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 唐岩 良地 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 細谷梨江 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 本田 龍一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平生 利恵子 018 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 荒木 竜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 下澤 治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 村本 治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上運天 治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 保利 修 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 泉 範明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 河野 龍登 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 牛久保　麻椰 111 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 神田　利一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 寄能 達也 086 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大西 良和 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大村 喜信 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大本 泰久 045 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小川 行弘 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西田 善一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み イェー イン ナイン 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 森島 裕治 029 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 森河　由紀弘 007 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮崎 嘉彦 039 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒岩 陽二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒田 祐次 084 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大野 雄二 069 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 今野 頼夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 勝間 夕紀恵 010 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 亀井 泰裕 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岩切　雄二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 今澤　義朗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 飯野 裕二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市山 勇仁 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市川　豊 011 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平川 雄大 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 日置 洋平 071 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 林 裕太 072 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 橋本 悠希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 河野 ゆかり 090 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 原 由里子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大薗 祐輝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡井　祐一 030 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 尾川 裕輝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上野 結菜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田中 悠太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大西 勇也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 熊谷 雄悦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大野 芳樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中島 吉近 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉盛　勇介 016 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 優樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 和田 行裕 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 植野 芳彦 098 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡部　有利子 042 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上田 志途 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 辻󠄀 葉子 063 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 富岡 良光 083 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 東元 保成 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田中 良典 040 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 髙岡 由依 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 立川 有紀美 004 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み ユン シュエ シン トン 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 塩澤 芳孝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 清水 由理 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 重村 祐也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 奥原 由香 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 都築　恭生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柏原 武琉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福岡 保則 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 巌 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小山 拓海 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大野　達也 070 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大熊 孝至 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西岡 拓海 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西川 友康 093 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 新岡 智也 023 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 生巣 武 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 仲田 毅 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長嶋 孝哉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長川 琢磨 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 盛 丈夫 057 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 力武　哲郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 望月 智美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三野 敏明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三成 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松田 健宏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 的場 敬 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 丸川　貴之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 前潟 孝行 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒永 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 久野木 哲也 050 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 工藤 正 025 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小西 武 033 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 北岡 太造 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三由 知英 106 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 相場　祐希 082 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐伯　翼 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 利光 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加藤 知生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 植田 倫徹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上村 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿部 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山本 隆信 043 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 木村　隆 056 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木 崇司 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤　隆 037 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中田 崇晴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 深澤 貴光 035 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み トゥイン ゾウ 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐竹 輝将 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉川 知行 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山口 貴也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 敏久 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 八尋 亨 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柳沼 太希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 筑紫 敏子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 照屋 忠彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 高柳 透 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 菅本 尚 034 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 島袋 武彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柴 利幸 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 澤田　卓冶 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉田　忠 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 内田 正宏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤 真大 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 竹村 雅幸 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡邉 英雄 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐々木 啓敦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 櫻井 秀憲 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 広 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 森宮 啓史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石橋 宏樹 060 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 堀越 宏喜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 端 啓貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安部 裕貴 104 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山口　大輝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉岡 英明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 横山 春佳 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山下 仁 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山口 晴久 038 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 英樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 八木 日香里 055 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 梅津 博幸 100 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 土谷 晴喜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 高根 大海 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田立 治彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉光 洋人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木 弘之 032 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 矢野 寛也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田村　夢有人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 一政 奏音 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 星野　薫 061 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 日隈 孝貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤 暁寧 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 重永 明日香 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 林田 克則 067 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 杉浦 章夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 諏訪邊 明 036 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 有藤 健太郎 022 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田　昭光 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 青木 鴻真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安藤 清 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 滝野澤　朱里 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 武田 純也 058 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 青塚 純平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿部　二郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 手柴 新 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 内藤　勲 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 駒田 一太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 舟川 勲 092 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田丸 明彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石亀 圭悟 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 杉村　寿人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 瀬尾 浩晃 088 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿曽 等 049 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安部 秀幸 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 矢野 葵 110 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 横塚 明美 101 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 木村 亮 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤 豪 012 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 行平 文彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西山 文弥 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 木山 史絵 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 藤岡　仁 105 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 檜垣 太 081 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 増澤 恵実子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 村中 大輔 064 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 近藤 篤史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 程 雯琪 107 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 武田 千秋 019 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（能登営業所） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（沖縄営業所） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（大阪支店） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（中部支店） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 悦子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 杉原 裕大 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平田 裕之 001 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 井出 波奈 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 英樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐竹 寛峻 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐々木 飛龍 026 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 櫻井　仁 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 坂口 英紀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鬼塚　宏明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 奥山 肇 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 那須 弘毅 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中山 寛之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 細谷 日菜子 080 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中道 秀則 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三浦 英智 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三村 ひとみ 065 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松永 秀彰 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 真殿 秀之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み トゥ リン 091 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 久下 大士 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小泉 博久 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川端 日向 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加藤 浩 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中川 浩一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 磐井 和貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平林 敬治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 笠野 克典 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市川 公映 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊部 正祥 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 細尾 舞雪 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 堀井 真紀子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 東田 将徳 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 濵嶋 学 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 蛭川 愛志 021 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福家 美緒 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 江崎 守 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石田　将貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 浅賀 雅彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加治屋 茜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小林 明夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 此島 有都 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡田 圭司 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 久木田　篤士 051 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松本 篤 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三輪 綾 089 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上川 功一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 明主 篤 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 池田 彩夏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西村 昭弘 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊東 美樹 017 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 神原　正明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口 守 002 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 篠田 萌衣 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中森 雅子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 澁谷 弥優 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大関 元生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大井 光治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 庭野　将紀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西山 真彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 奈須野　萌 028 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 梶原　美砂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 成田 満 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 深澤 淳 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 永波 基哉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 村井 道秀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松本　三千男 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松井 正人 008 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 丸田 雅博 099 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 桑田 昌季 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小路 真由 085 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川原　正人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中谷 正広 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐々木　勝征 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮本 綾 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中村 加奈子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大山　顯一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小笠　浩史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 野村 一義 003 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長野 和雄 097 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 睦　堅斗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮崎 克晶 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮島 杏花 109 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松浦 景子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 前田 和之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡田 健司 095 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒田　和彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 古賀 圭介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小平 浩二 062 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小林　薫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 北澤 克也 066 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岸川 心美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 劔持 久美子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川名 啓介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川元　孝一郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 河北 勝己 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小松 敬 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 恵子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大内 碧人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柴田 鋼三 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小森 一典 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 近川 和郎 094 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 四塚 絢登 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉田 京平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安本　翔 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 矢野 勝己 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 恭平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 相良 宏介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 脇平 興一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上田 浩二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 綱分 康太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡　欣一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口 航平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 富岡 康丞 047 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 志田 和人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 勝呂 和之 068 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 須原 研二 079 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 戸邉 慶太郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 竹内 和也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 髙谷　和希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中村 泰子 1 Microsoft 365 Business Basic (レガシー) ¥1,000 不明 アクティブ 最適化済み 田島 美知 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （横浜営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（千葉営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（北海道支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（東北支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（東京支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （有明営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み Amazonビジネス 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（本社） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （青森営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （北陸営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（茨城営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （四国営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 小原　恒平 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 会計サポート 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（中部） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（北海道） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（九州） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（大阪） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（東京） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 普天間 倫世 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （北九州営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （大阪支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （沖縄営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （九州支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （能登営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 仕訳入力システム通知用 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （静岡営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 総務（支払） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み システムインフォ 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 坊垣 丈義 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（北陸営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（中国支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（四国営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札 （九州支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （千葉営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （中部支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （中国営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（横浜営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み エンジニアリング部電子請求書用 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算（東京工事事務所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （東京支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （東北支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 技術 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （北海道支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （茨城営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み みらい建設工業 人事採用 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み Fortinet管理 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 財務管理 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み"""
    
    # データを解析
    user_entries = []
    parts = user_data_text.split()
    i = 0
    while i < len(parts):
        if i + 6 < len(parts):
            # ユーザー名を組み立て（部署コードが数字の場合を考慮）
            name_parts = []
            j = i
            while j < len(parts) and not parts[j].isdigit():
                name_parts.append(parts[j])
                j += 1
            
            if j < len(parts):
                name = ' '.join(name_parts)
                
                # 部署コード（数字）をチェック
                dept = ""
                if j < len(parts) and parts[j].isdigit() and len(parts[j]) <= 3:
                    dept = parts[j]
                    j += 1
                
                # 残りの情報を取得
                if j + 5 < len(parts):
                    license_count = parts[j] if j < len(parts) else "1"
                    j += 1
                    
                    # ライセンス種別を取得（複数の単語の場合もある）
                    license_parts = []
                    license_start = j
                    while j < len(parts) and not parts[j].startswith('¥'):
                        license_parts.append(parts[j])
                        j += 1
                    license_type = ' '.join(license_parts)
                    
                    # コストを取得
                    cost = parts[j] if j < len(parts) and parts[j].startswith('¥') else "¥0"
                    j += 1
                    
                    # 残りの情報
                    last_signin = parts[j] if j < len(parts) else "不明"
                    j += 1
                    status = parts[j] if j < len(parts) else "アクティブ"
                    j += 1
                    optimization = parts[j] if j < len(parts) else "最適化済み"
                    j += 1
                    
                    user_entries.append({
                        'name': name,
                        'dept': dept,
                        'license_count': license_count,
                        'license_type': license_type,
                        'cost': cost,
                        'last_signin': last_signin,
                        'status': status,
                        'optimization': optimization
                    })
                    
                    i = j
                else:
                    i += 1
            else:
                i += 1
        else:
            i += 1
    
    print(f"解析完了: {len(user_entries)}名のユーザーデータを処理しました")
    
    # ライセンス種別でソート（E3 → Exchange → Basic）
    def license_sort_key(user):
        license = user['license_type']
        if 'Microsoft 365 E3' in license:
            return (1, user['name'])
        elif 'Exchange Online Plan 2' in license:
            return (2, user['name'])
        else:
            return (3, user['name'])
    
    user_entries.sort(key=license_sort_key)
    
    # CSVファイルを生成
    output_path = "/mnt/e/MicrosoftProductManagementTools/Reports/Monthly/Clean_Complete_User_License_Details.csv"
    with open(output_path, 'w', encoding='utf-8-sig', newline='') as csvfile:
        fieldnames = [
            'No',
            'ユーザー名',
            '部署コード',
            'ライセンス数',
            'ライセンス種別',
            '月額コスト',
            '最終サインイン',
            '利用状況',
            '最適化状況'
        ]
        
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        for index, user in enumerate(user_entries, 1):
            department = user['dept'] if user['dept'] else '-'
            
            writer.writerow({
                'No': index,
                'ユーザー名': user['name'],
                '部署コード': department,
                'ライセンス数': user['license_count'],
                'ライセンス種別': user['license_type'],
                '月額コスト': user['cost'],
                '最終サインイン': user['last_signin'],
                '利用状況': user['status'],
                '最適化状況': user['optimization']
            })
    
    # ライセンス別統計情報を生成
    e3_users = [u for u in user_entries if 'Microsoft 365 E3' in u['license_type']]
    exchange_users = [u for u in user_entries if 'Exchange Online Plan 2' in u['license_type']]
    basic_users = [u for u in user_entries if 'Business Basic' in u['license_type']]
    
    total_cost = 0
    for user in user_entries:
        cost_str = user['cost'].replace('¥', '').replace(',', '')
        if cost_str.isdigit():
            total_cost += int(cost_str)
    
    # 統計情報CSVも生成
    stats_csv_path = output_path.replace('.csv', '_統計情報.csv')
    with open(stats_csv_path, 'w', encoding='utf-8-sig', newline='') as csvfile:
        fieldnames = ['項目', '数量', '備考']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        writer.writerow({'項目': 'Microsoft 365 E3ライセンス', '数量': f'{len(e3_users)}ユーザー', '備考': '¥2,840/月'})
        writer.writerow({'項目': 'Exchange Online Plan 2ライセンス', '数量': f'{len(exchange_users)}ユーザー', '備考': '¥960/月'})
        writer.writerow({'項目': 'Business Basic ライセンス', '数量': f'{len(basic_users)}ユーザー', '備考': '¥1,000/月'})
        writer.writerow({'項目': '総ユーザー数', '数量': f'{len(user_entries)}ユーザー', '備考': '全ライセンス合計'})
        writer.writerow({'項目': '総月額コスト', '数量': f'¥{total_cost:,}', '備考': '全ライセンス合計'})
        writer.writerow({'項目': '平均コスト/ユーザー', '数量': f'¥{total_cost // len(user_entries) if user_entries else 0:,}', '備考': '月額平均'})
        writer.writerow({'項目': '生成日時', '数量': datetime.now().strftime('%Y年%m月%d日 %H:%M:%S'), '備考': 'システム生成'})
    
    print(f"綺麗に整理されたCSVファイルを生成しました: {output_path}")
    print(f"統計情報CSVファイルを生成しました: {stats_csv_path}")
    print(f"総ユーザー数: {len(user_entries)}名")
    print(f"Microsoft 365 E3: {len(e3_users)}名")
    print(f"Exchange Online Plan 2: {len(exchange_users)}名")
    print(f"Business Basic: {len(basic_users)}名")
    print(f"総月額コスト: ¥{total_cost:,}")

if __name__ == "__main__":
    main()