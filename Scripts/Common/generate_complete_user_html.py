#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
提供されたユーザーデータから完全なHTMLファイルを生成するPythonスクリプト
"""

import sys
from datetime import datetime

def main():
    # 提供されたユーザーデータを解析
    user_data_text = """荒木 厚史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 奨 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤　慎太郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小野 昭司 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鬼丸 覚 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 新次 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大谷　伸介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小笠原 秀光 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 野村 信二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中山 新吾 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中野 慎一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長岡 伸一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 進藤　愁也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長江 進 052 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小島 栄 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川村　慎二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上村 爽空 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 神川 里美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 泉 誠司郎 046 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岩崎　志門 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 茂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 池田 紳之介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 堀　聡 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 東 正真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 服部 俊朗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 今　真吾 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 後野 秀一郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 塩野谷　咲希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口　純代 027 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岩崎 泰治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石原 敏彦 059 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 稲毛 健 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市岡 匠 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 羽矢崎 友香 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 服部 恒夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 濱田 高明 053 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福田 猛 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 藤原 鼓 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 江原 知希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 赤坂 聡哉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 染川 紗杏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿知良 巧 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 多田 翔伍 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 栗原 竣介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石原 慎太郎 041 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 藤原 伸治 078 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加藤 里美 020 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 聡 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉江 真一 087 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 津田 颯太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 坪井 俊太朗 009 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 友清 真一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 玉木 茂樹 077 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 尾方 柊真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 門田　利治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福田 総一郎 048 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木　崚太 103 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 武村 奈穂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 高田 七奈 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 砂子 範行 076 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 菅波 則克 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大崎 経生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 直美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 永江 愛美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 貴志 直稀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 井上 渚沙 108 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 服部　登 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 畑岡 直樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 寺本 信人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 有田　尚史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡辺 光男 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤　淳 054 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡邉　真澄 024 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口　愛美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み ザーニ トェイ 073 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長谷川　茉侑 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 足立 雅樹 044 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉冨　三矢 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柳沢 真穂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山本 美由貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊藤 桃子 014 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 富 靖閔 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 登坂 成葉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉谷 直樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山﨑　龍馬 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田島 陸豊 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木 龍一 006 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 下田 伶央斗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大久保 澪弥 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小笠原 涼子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大日方 亮汰 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 野口 藍 031 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西田 竜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 新倉 怜於 005 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中畑 亮一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡邉 なおみ 015 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松尾 蓮 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小堀 諒士 075 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 唐岩 良地 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 細谷梨江 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 本田 龍一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平生 利恵子 018 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 荒木 竜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 下澤 治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 村本 治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上運天 治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 保利 修 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 泉 範明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 河野 龍登 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 牛久保　麻椰 111 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 神田　利一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 寄能 達也 086 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大西 良和 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大村 喜信 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大本 泰久 045 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小川 行弘 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西田 善一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み イェー イン ナイン 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 森島 裕治 029 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 森河　由紀弘 007 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮崎 嘉彦 039 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒岩 陽二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒田 祐次 084 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大野 雄二 069 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 今野 頼夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 勝間 夕紀恵 010 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 亀井 泰裕 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岩切　雄二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 今澤　義朗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 飯野 裕二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市山 勇仁 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市川　豊 011 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平川 雄大 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 日置 洋平 071 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 林 裕太 072 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 橋本 悠希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 河野 ゆかり 090 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 原 由里子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大薗 祐輝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡井　祐一 030 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 尾川 裕輝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上野 結菜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田中 悠太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大西 勇也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 熊谷 雄悦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大野 芳樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中島 吉近 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉盛　勇介 016 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 優樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 和田 行裕 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 植野 芳彦 098 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡部　有利子 042 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上田 志途 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 辻󠄀 葉子 063 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 富岡 良光 083 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 東元 保成 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田中 良典 040 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 髙岡 由依 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 立川 有紀美 004 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み ユン シュエ シン トン 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 塩澤 芳孝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 清水 由理 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 重村 祐也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 奥原 由香 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 都築　恭生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柏原 武琉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福岡 保則 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 巌 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小山 拓海 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大野　達也 070 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大熊 孝至 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西岡 拓海 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西川 友康 093 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 新岡 智也 023 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 生巣 武 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 仲田 毅 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長嶋 孝哉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長川 琢磨 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 盛 丈夫 057 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 力武　哲郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 望月 智美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三野 敏明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三成 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松田 健宏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 的場 敬 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 丸川　貴之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 前潟 孝行 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒永 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 久野木 哲也 050 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 工藤 正 025 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小西 武 033 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 北岡 太造 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三由 知英 106 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 相場　祐希 082 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐伯　翼 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 利光 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加藤 知生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 植田 倫徹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上村 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿部 哲也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山本 隆信 043 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 木村　隆 056 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木 崇司 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤　隆 037 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中田 崇晴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 深澤 貴光 035 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み トゥイン ゾウ 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐竹 輝将 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉川 知行 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山口 貴也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 敏久 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 八尋 亨 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柳沼 太希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 筑紫 敏子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 照屋 忠彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 高柳 透 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 菅本 尚 034 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 島袋 武彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柴 利幸 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 澤田　卓冶 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉田　忠 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 内田 正宏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤 真大 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 竹村 雅幸 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡邉 英雄 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐々木 啓敦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 櫻井 秀憲 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 広 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 森宮 啓史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石橋 宏樹 060 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 堀越 宏喜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 端 啓貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安部 裕貴 104 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山口　大輝 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉岡 英明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 横山 春佳 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山下 仁 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山口 晴久 038 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 英樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 八木 日香里 055 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 梅津 博幸 100 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 土谷 晴喜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 高根 大海 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田立 治彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉光 洋人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鈴木 弘之 032 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 矢野 寛也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田村　夢有人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 一政 奏音 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 星野　薫 061 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 日隈 孝貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤 暁寧 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 重永 明日香 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 林田 克則 067 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 杉浦 章夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 諏訪邊 明 036 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 有藤 健太郎 022 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田　昭光 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 青木 鴻真 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安藤 清 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 滝野澤　朱里 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 武田 純也 058 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 青塚 純平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿部　二郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 手柴 新 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 内藤　勲 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 駒田 一太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 舟川 勲 092 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田丸 明彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石亀 圭悟 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 杉村　寿人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 瀬尾 浩晃 088 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 阿曽 等 049 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安部 秀幸 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 矢野 葵 110 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 横塚 明美 101 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 木村 亮 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 齋藤 豪 012 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 行平 文彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西山 文弥 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 木山 史絵 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 藤岡　仁 105 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 檜垣 太 081 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 増澤 恵実子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 村中 大輔 064 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 近藤 篤史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 程 雯琪 107 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 武田 千秋 019 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（能登営業所） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（沖縄営業所） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（大阪支店） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 電子入札（中部支店） 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 悦子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 杉原 裕大 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平田 裕之 001 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 井出 波奈 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐藤 英樹 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐竹 寛峻 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐々木 飛龍 026 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 櫻井　仁 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 坂口 英紀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 鬼塚　宏明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 奥山 肇 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 那須 弘毅 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中山 寛之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 細谷 日菜子 080 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中道 秀則 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三浦 英智 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三村 ひとみ 065 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松永 秀彰 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 真殿 秀之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み トゥ リン 091 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 久下 大士 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小泉 博久 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川端 日向 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加藤 浩 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中川 浩一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 磐井 和貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 平林 敬治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 笠野 克典 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 市川 公映 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊部 正祥 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 細尾 舞雪 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 堀井 真紀子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 東田 将徳 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 濵嶋 学 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 蛭川 愛志 021 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 福家 美緒 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 江崎 守 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 石田　将貴 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 浅賀 雅彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 加治屋 茜 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小林 明夫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 此島 有都 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡田 圭司 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 久木田　篤士 051 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松本 篤 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 三輪 綾 089 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上川 功一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 明主 篤 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 池田 彩夏 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西村 昭弘 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 伊東 美樹 017 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 神原　正明 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口 守 002 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 篠田 萌衣 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中森 雅子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 澁谷 弥優 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大関 元生 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大井 光治 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 庭野　将紀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 西山 真彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 奈須野　萌 028 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 梶原　美砂 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 成田 満 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 深澤 淳 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 永波 基哉 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 村井 道秀 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松本　三千男 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松井 正人 008 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 丸田 雅博 099 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 桑田 昌季 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小路 真由 085 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川原　正人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中谷 正広 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 佐々木　勝征 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮本 綾 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中村 加奈子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大山　顯一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小笠　浩史 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 野村 一義 003 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 長野 和雄 097 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 睦　堅斗 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮崎 克晶 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 宮島 杏花 109 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 松浦 景子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 前田 和之 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡田 健司 095 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 黒田　和彦 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 古賀 圭介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小平 浩二 062 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小林　薫 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 北澤 克也 066 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岸川 心美 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 劔持 久美子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川名 啓介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 川元　孝一郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 河北 勝己 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小松 敬 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 岡本 恵子 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 大内 碧人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 柴田 鋼三 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 小森 一典 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 近川 和郎 094 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 四塚 絢登 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 吉田 京平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 安本　翔 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 矢野 勝己 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 山田 恭平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 相良 宏介 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 脇平 興一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 上田 浩二 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 綱分 康太 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 渡　欣一 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 田口 航平 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 富岡 康丞 047 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 志田 和人 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 勝呂 和之 068 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 須原 研二 079 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 戸邉 慶太郎 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 竹内 和也 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 髙谷　和希 1 Microsoft 365 E3 ¥2,840 不明 アクティブ 最適化済み 中村 泰子 1 Microsoft 365 Business Basic (レガシー) ¥1,000 不明 アクティブ 最適化済み 田島 美知 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （横浜営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（千葉営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（北海道支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（東北支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（東京支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （有明営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み Amazonビジネス 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（本社） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （青森営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （北陸営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（茨城営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （四国営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 小原　恒平 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 会計サポート 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（中部） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（北海道） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（九州） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（大阪） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 管理（東京） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 普天間 倫世 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （北九州営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （大阪支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （沖縄営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （九州支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （能登営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 仕訳入力システム通知用 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （静岡営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 総務（支払） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み システムインフォ 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 坊垣 丈義 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（北陸営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（中国支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（四国営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札 （九州支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （千葉営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （中部支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （中国営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 電子入札（横浜営業支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み エンジニアリング部電子請求書用 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算（東京工事事務所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （東京支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （東北支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 技術 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （北海道支店） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 楽楽精算 （茨城営業所） 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み みらい建設工業 人事採用 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み Fortinet管理 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み 財務管理 1 Exchange Online Plan 2 ¥960 不明 アクティブ 最適化済み"""
    
    # データを解析
    user_entries = []
    current_entry = []
    
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
    
    # ライセンス別統計を計算
    e3_users = [u for u in user_entries if 'Microsoft 365 E3' in u['license_type']]
    exchange_users = [u for u in user_entries if 'Exchange Online Plan 2' in u['license_type']]
    basic_users = [u for u in user_entries if 'Business Basic' in u['license_type']]
    
    total_cost = 0
    for user in user_entries:
        cost_str = user['cost'].replace('¥', '').replace(',', '')
        if cost_str.isdigit():
            total_cost += int(cost_str)
    
    # HTMLコンテンツを生成
    html_content = f'''<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft 365ライセンス分析ダッシュボード - 完全修正版</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{ 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; padding: 20px;
            background-color: #f5f5f5; 
            color: #333;
            line-height: 1.6;
        }}
        .header {{ 
            background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%); 
            color: white; 
            padding: 30px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
            text-align: center;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }}
        .header h1 {{ margin: 0; font-size: 28px; }}
        .header .subtitle {{ margin: 10px 0 0 0; font-size: 16px; opacity: 0.9; }}
        
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        .summary-card {{
            background: white;
            padding: 25px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            border-left: 5px solid #0078d4;
        }}
        .summary-card h3 {{ 
            margin: 0 0 15px 0; 
            color: #666; 
            font-size: 16px; 
            font-weight: 600;
        }}
        .summary-card .value {{ 
            font-size: 36px; 
            font-weight: bold; 
            margin: 10px 0 15px 0; 
            color: #0078d4; 
        }}
        .summary-card .description {{ 
            color: #888; 
            font-size: 14px; 
            margin: 0;
        }}
        
        .controls-section {{
            background: white;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 25px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }}
        .controls-section h3 {{
            margin: 0 0 20px 0;
            color: #333;
            font-size: 18px;
        }}
        .filter-controls {{
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
            margin-bottom: 20px;
        }}
        .filter-controls input, .filter-controls select {{
            padding: 10px 15px;
            border: 2px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
            min-width: 180px;
        }}
        .filter-controls input:focus, .filter-controls select:focus {{
            outline: none;
            border-color: #0078d4;
        }}
        .filter-controls button {{
            padding: 10px 20px;
            background: #0078d4;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: background-color 0.3s;
        }}
        .filter-controls button:hover {{
            background: #106ebe;
        }}
        .filter-controls button.export {{
            background: #28a745;
        }}
        .filter-controls button.export:hover {{
            background: #218838;
        }}
        
        .table-container {{
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .table-header {{
            background: linear-gradient(135deg, #6c757d 0%, #5a6268 100%);
            color: white;
            padding: 20px 25px;
            font-weight: bold;
            font-size: 18px;
        }}
        .table-wrapper {{
            max-height: 700px;
            overflow-y: auto;
            border: 1px solid #ddd;
        }}
        .data-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }}
        .data-table thead th {{
            background-color: #0078d4;
            color: white;
            border: 1px solid #0078d4;
            padding: 15px 12px;
            text-align: left;
            font-weight: 600;
            position: sticky;
            top: 0;
            z-index: 10;
        }}
        .data-table tbody td {{
            border: 1px solid #e0e0e0;
            padding: 12px;
            font-size: 13px;
        }}
        .data-table tbody tr:nth-child(even) {{
            background-color: #f8f9fa;
        }}
        .data-table tbody tr:hover {{
            background-color: #e3f2fd;
            cursor: pointer;
        }}
        
        /* ライセンス種別による色分け */
        .license-e3 {{ 
            background-color: #e3f2fd !important; 
            border-left: 4px solid #2196f3;
        }}
        .license-exchange {{ 
            background-color: #e8f5e8 !important; 
            border-left: 4px solid #4caf50;
        }}
        .license-basic {{ 
            background-color: #fff3e0 !important; 
            border-left: 4px solid #ff9800;
        }}
        
        .stats-footer {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 15px;
            padding: 20px 25px;
            background: #f8f9fa;
            border-top: 3px solid #0078d4;
            font-size: 13px;
        }}
        .stats-footer > div {{
            text-align: center;
            padding: 10px;
        }}
        .stats-footer .label {{
            font-weight: 600;
            color: #666;
            display: block;
            margin-bottom: 5px;
        }}
        .stats-footer .value {{
            font-size: 20px;
            color: #0078d4;
            font-weight: bold;
        }}
        
        .footer {{ 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-top: 40px; 
            padding: 25px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>👥 Microsoft 365ライセンス分析ダッシュボード - 完全修正版</h1>
        <div class="subtitle">みらい建設工業株式会社 - 全ユーザーライセンス情報</div>
        <div class="subtitle">生成日時: {datetime.now().strftime('%Y年%m月%d日 %H:%M:%S')}</div>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>Microsoft 365 E3</h3>
            <div class="value">{len(e3_users)}</div>
            <div class="description">ユーザー（¥2,840/月）</div>
        </div>
        <div class="summary-card">
            <h3>Exchange Online Plan 2</h3>
            <div class="value">{len(exchange_users)}</div>
            <div class="description">ユーザー（¥960/月）</div>
        </div>
        <div class="summary-card">
            <h3>Business Basic (レガシー)</h3>
            <div class="value">{len(basic_users)}</div>
            <div class="description">ユーザー（¥1,000/月）</div>
        </div>
        <div class="summary-card">
            <h3>総月額コスト</h3>
            <div class="value">¥{total_cost:,}</div>
            <div class="description">現在の支出</div>
        </div>
        <div class="summary-card">
            <h3>総ユーザー数</h3>
            <div class="value">{len(user_entries)}</div>
            <div class="description">全ライセンス合計</div>
        </div>
        <div class="summary-card">
            <h3>平均コスト/ユーザー</h3>
            <div class="value">¥{total_cost // len(user_entries) if user_entries else 0:,}</div>
            <div class="description">月額平均</div>
        </div>
    </div>

    <div class="controls-section">
        <h3>🔍 検索・フィルター・エクスポート</h3>
        <div class="filter-controls">
            <input type="text" id="searchInput" placeholder="ユーザー名で検索..." onkeyup="filterTable()">
            <select id="licenseFilter" onchange="filterTable()">
                <option value="">全ライセンス</option>
                <option value="Microsoft 365 E3">Microsoft 365 E3</option>
                <option value="Exchange Online Plan 2">Exchange Online Plan 2</option>
                <option value="Business Basic">Business Basic (レガシー)</option>
            </select>
            <select id="departmentFilter" onchange="filterTable()">
                <option value="">全部署</option>
                <option value="has-dept">部署コードあり</option>
                <option value="no-dept">部署コードなし</option>
            </select>
            <button onclick="clearFilters()">フィルタークリア</button>
            <button class="export" onclick="exportToCSV()">CSV出力</button>
        </div>
    </div>

    <div class="table-container">
        <div class="table-header" id="tableHeader">📋 ライセンス割り当てユーザー詳細一覧（全{len(user_entries)}名）</div>
        <div class="table-wrapper">
            <table class="data-table" id="userTable">
                <thead>
                    <tr>
                        <th style="width: 60px;">No.</th>
                        <th style="width: 200px;">ユーザー名</th>
                        <th style="width: 100px;">部署コード</th>
                        <th style="width: 250px;">ライセンス種別</th>
                        <th style="width: 120px;">月額コスト</th>
                        <th style="width: 100px;">最終サインイン</th>
                        <th style="width: 100px;">利用状況</th>
                        <th style="width: 120px;">最適化状況</th>
                    </tr>
                </thead>
                <tbody id="userTableBody">'''

    # ユーザーデータのテーブル行を生成
    for index, user in enumerate(user_entries, 1):
        department = user['dept'] if user['dept'] else '-'
        license_type = user['license_type']
        
        # ライセンス種別によるCSSクラス決定
        if 'Microsoft 365 E3' in license_type:
            license_class = 'license-e3'
        elif 'Exchange Online Plan 2' in license_type:
            license_class = 'license-exchange'
        else:
            license_class = 'license-basic'
        
        html_content += f'''
                    <tr class="{license_class}">
                        <td>{index}</td>
                        <td><strong>{user['name']}</strong></td>
                        <td>{department}</td>
                        <td>{license_type}</td>
                        <td>{user['cost']}</td>
                        <td>{user['last_signin']}</td>
                        <td>{user['status']}</td>
                        <td>{user['optimization']}</td>
                    </tr>'''

    # HTMLの残り部分を追加
    html_content += f'''
                </tbody>
            </table>
        </div>
        
        <div class="stats-footer">
            <div><span class="label">表示中</span><span class="value" id="visibleCount">{len(user_entries)}</span></div>
            <div><span class="label">Microsoft 365 E3</span><span class="value">{len(e3_users)}</span></div>
            <div><span class="label">Exchange Online Plan 2</span><span class="value">{len(exchange_users)}</span></div>
            <div><span class="label">Business Basic</span><span class="value">{len(basic_users)}</span></div>
            <div><span class="label">総ユーザー数</span><span class="value">{len(user_entries)}</span></div>
            <div><span class="label">平均コスト/ユーザー</span><span class="value">¥{total_cost // len(user_entries) if user_entries else 0:,}</span></div>
        </div>
    </div>

    <div class="footer">
        <p><strong>このレポートは Microsoft 365 ライセンス管理システムにより自動生成されました</strong></p>
        <p>ITSM/ISO27001/27002準拠 | みらい建設工業株式会社 ライセンス最適化センター</p>
        <p>🤖 Generated with Claude Code</p>
    </div>

    <script>
        // フィルター機能
        function filterTable() {{
            const searchInput = document.getElementById('searchInput').value.toLowerCase();
            const licenseFilter = document.getElementById('licenseFilter').value;
            const departmentFilter = document.getElementById('departmentFilter').value;
            const tableBody = document.getElementById('userTableBody');
            const rows = tableBody.getElementsByTagName('tr');

            let visibleCount = 0;
            for (let i = 0; i < rows.length; i++) {{
                const row = rows[i];
                const userName = row.cells[1] ? row.cells[1].textContent.toLowerCase() : '';
                const license = row.cells[3] ? row.cells[3].textContent : '';
                const department = row.cells[2] ? row.cells[2].textContent : '';
                
                let showRow = true;

                if (searchInput && !userName.includes(searchInput)) {{
                    showRow = false;
                }}

                if (licenseFilter && !license.includes(licenseFilter)) {{
                    showRow = false;
                }}

                if (departmentFilter === 'has-dept' && department === '-') {{
                    showRow = false;
                }} else if (departmentFilter === 'no-dept' && department !== '-') {{
                    showRow = false;
                }}

                row.style.display = showRow ? '' : 'none';
                if (showRow) visibleCount++;
            }}
            
            document.getElementById('tableHeader').textContent = `📋 ライセンス割り当てユーザー詳細一覧（表示中: ${{visibleCount}}名 / 全{len(user_entries)}名）`;
            document.getElementById('visibleCount').textContent = visibleCount;
        }}

        // フィルタークリア
        function clearFilters() {{
            document.getElementById('searchInput').value = '';
            document.getElementById('licenseFilter').value = '';
            document.getElementById('departmentFilter').value = '';
            filterTable();
        }}

        // CSV出力
        function exportToCSV() {{
            const visibleRows = [];
            const tableBody = document.getElementById('userTableBody');
            const rows = tableBody.getElementsByTagName('tr');
            
            // ヘッダー
            visibleRows.push(['No.', 'ユーザー名', '部署コード', 'ライセンス種別', '月額コスト', '最終サインイン', '利用状況', '最適化状況']);
            
            // 表示中の行のみ
            for (let i = 0; i < rows.length; i++) {{
                const row = rows[i];
                if (row.style.display !== 'none') {{
                    const rowData = [];
                    for (let j = 0; j < row.cells.length; j++) {{
                        rowData.push(row.cells[j].textContent);
                    }}
                    visibleRows.push(rowData);
                }}
            }}
            
            // CSV形式に変換
            const csvContent = visibleRows.map(row => 
                row.map(cell => `"${{cell}}"`).join(',')
            ).join('\\n');
            
            // ダウンロード
            const blob = new Blob([csvContent], {{ type: 'text/csv;charset=utf-8;' }});
            const link = document.createElement('a');
            const url = URL.createObjectURL(blob);
            link.setAttribute('href', url);
            link.setAttribute('download', 'license_users_' + new Date().toISOString().split('T')[0] + '.csv');
            link.style.visibility = 'hidden';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }}
    </script>
</body>
</html>'''

    # HTMLファイルに出力
    output_path = "/mnt/e/MicrosoftProductManagementTools/Reports/Monthly/License_Analysis_Dashboard_Fixed_Complete.html"
    with open(output_path, 'w', encoding='utf-8') as htmlfile:
        htmlfile.write(html_content)
    
    print(f"完全修正されたHTMLファイルを生成しました: {output_path}")
    print(f"総ユーザー数: {len(user_entries)}名")
    print(f"Microsoft 365 E3: {len(e3_users)}名")
    print(f"Exchange Online Plan 2: {len(exchange_users)}名")
    print(f"Business Basic: {len(basic_users)}名")
    print(f"総月額コスト: ¥{total_cost:,}")

if __name__ == "__main__":
    main()