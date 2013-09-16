package SortCatFldMover::L10N::ja;

use strict;
use base 'SortCatFldMover::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
    # config.yaml
    'Hajime Fujimoto' => '藤本　壱',
    'Mover plugin from SortCatFld plugin to Movable Type 5.1+ native category / folder sorting function.' => 'SortCatFldプラグインから、Movable Type 5.1以降標準のカテゴリ／フォルダ並べ替え機能への移行を行います。',

    # system_config.tmpl
    'Move to Movable Type 5.1+' => 'Movable Type 5.1以降へ移行',
    'Move all order info to Movable Type 5.1+' => 'すべての並び順の情報をMovable Type 5.1以降へ移行',
    'Move order info of selected websites and / or blogs to Movable Type 5.1+' => '選択したウェブサイトとブログの並び順の情報をMovable Type 5.1以降へ移行',

    # blog_config.tmpl
    'Move order info of this website to Movable Type 5.1' => 'このウェブサイトの並び順の情報をMovable Type 5.1へ移行',
    'Move order info of this blog to Movable Type 5.1' => 'このブログの並び順の情報をMovable Type 5.1へ移行',
    'Move order info of this website and child blogs to Movable Type 5.1' => 'このウェブサイトと配下のブログの並び順の情報をMovable Type 5.1へ移行',

    # select_blogs.tmpl
    'Select websites / blogs' => 'ウェブサイト／ブログを選択',
    'Website / Blog' => 'ウェブサイト／ブログ',

    # move_start.tmpl
    'Move order info to Movable Type 5.1+' => '並び順の情報をMovable Type 5.1以降に移行',
    "Moved sort order information of [_1] '[_2]'." => '[_1]「[_2]」の並び順の情報を移行しました。',
    'Moving sort order information finished.' => '並び順の情報の移行を完了しました。',
    'Error occured : [_1].' => 'エラーが発生しました。 ： [_1]',

    # CMS.pm
    'You are not an administrator.' => '管理者権限がありません',
    'No name' => '無題',
);

1;
