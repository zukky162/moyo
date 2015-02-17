%% @copyright 2013-2014 DWANGO Co., Ltd. All Rights Reserved.
%%
%% @doc バイナリに関する処理を集めたユーティリティモジュール.
-module(moyo_binary).

%%----------------------------------------------------------------------------------------------------------------------
%% Exported API
%%----------------------------------------------------------------------------------------------------------------------
-export([
         to_hex/1,
         from_hex/1,
         to_binary/1,
         try_binary_to_existing_atom/2,
         format/2,
         generate_random_list/2,
         to_float/1,
         to_number/1,
         strip/1,
         strip/2,
         strip/3,
         strip/4,
         abbreviate/2,
         abbreviate/3,
         tr/2,
         fill/2,
         join/2,
         fixed_point_binary_to_number/3,
         number_to_fixed_point_binary/3
        ]).

%%----------------------------------------------------------------------------------------------------------------------
%% Exported Functions
%%----------------------------------------------------------------------------------------------------------------------

%% @doc 生のバイナリを16進数表記のバイナリに変換する.
%%
%% 16進数のアルファベット部分は、常に小文字が使用される. <br />
%% ex:
%% ```
%% > moyo_binary:to_hex(<<"ab_YZ">>).
%% <<"61625f595a">>
%% '''
-spec to_hex(Raw::binary()) -> Encoded::binary().
to_hex(Raw) ->
    Table = <<"0123456789abcdef">>,
    list_to_binary([binary:at(Table, Nibble) || <<Nibble:4>> <= Raw]).

%% @doc 16進数表記のバイナリを生のバイナリに変換する.
%% [0-9a-zA-Z]にマッチしない文字がある場合は {invalid_hex_binary, Input} error が発生する
%%
%% ex:
%% ```
%% > moyo_binary:from_hex(<<"61625f595a">>).
%% <<"ab_YZ">>
%% '''
-spec from_hex(Encoded::binary()) -> Raw::binary().
from_hex(Encoded) ->
    %% ASCII -> hex value table. valid value is in [0, 16). table size is 256.
    Table =
        <<
          %% 0x00-0x1F
          "Control chars   ", "moyo is good yay",
          " ! #$%&'()*+,-./",
          %% 0-9 ("0" is 0x30)
          16#0:8,16#1:8,16#2:8,16#3:8,16#4:8,16#5:8,16#6:8,16#7:8,16#8:8,16#9:8,":;<=>?",
          %% A-F ("A" is 0x41)
          "@", 16#A:8, 16#B:8, 16#C:8, 16#D:8, 16#E:8, 16#F:8, "GHIJKLMNOPQRSTUVWXYZ[ ]^_",
          %% a-f ("a" is 0x61)
          "`", 16#A:8, 16#B:8, 16#C:8, 16#D:8, 16#E:8, 16#F:8, "ghijklmnopqrstuvwxyz{|}~ ",
          %% 0x80-0xFF
          "TODO: Write nice poem here                                      ",
          "                                                                "
        >>,
    EncodedFilled = case byte_size(Encoded) rem 2 of
                        1 -> <<"0", Encoded/binary>>;
                        0 -> Encoded
                    end,
    Packer = fun(N0, N1) -> case N0 bor N1 of
                                N when N >= 16 -> error({invalid_hex_binary, Encoded});
                                _ -> <<N0:4, N1:4>>
                            end end,
    list_to_binary([Packer(binary:at(Table, N0), binary:at(Table, N1))
                    || <<N0:8, N1:8>> <= EncodedFilled]).

%% @doc Erlangの項をバイナリに変換する
%%
%% ユニコード値のリスト(文字列)を、UTF-8バイナリ列に変換したい場合は`unicode'モジュールを使用すること.
-spec to_binary(term()) -> binary().
to_binary(V) when is_binary(V)   -> V;
to_binary(V) when is_atom(V)     -> atom_to_binary(V, utf8);
to_binary(V) when is_integer(V)  -> integer_to_binary(V);
to_binary(V) when is_float(V)    -> float_to_binary(V);
to_binary(V)                     -> list_to_binary(moyo_string:to_string(V)).

%% @doc バイナリのアトムへの変換を試みる.
%%
%% バイナリに対応するアトムが既に存在する場合は、そのアトムを返し、存在しない場合は元のバイナリを返す.
-spec try_binary_to_existing_atom(binary(), Encoding) -> binary() | atom() when
      Encoding :: latin1 | unicode | utf8.
try_binary_to_existing_atom(Binary, Encodeing) ->
    try
        binary_to_existing_atom(Binary, Encodeing)
    catch
        _:_ -> Binary
    end.

%% @doc 指定されたフォーマットのバイナリを生成して返す.
%%
%% `list_to_binary(io_lib:format(Format, Data))'と同等.
-spec format(Format, Data) -> binary() when
      Format :: io:format(),
      Data   :: [term()].
format(Format, Data) ->
    list_to_binary(io_lib:format(Format, Data)).

%% @doc ランダム かつ ユニークな要素(バイナリ)を`Count'個含むリストを生成する.
-spec generate_random_list(non_neg_integer(), non_neg_integer()) -> [binary()].
generate_random_list(ByteSize, Count) ->
    generate_random_list(ByteSize, Count, []).

%% @doc バイナリを小数に変換する.
%%
%% {@link erlang:binary_to_float/1}とは異なり`<<"5">>'のような整数を表すバイナリも小数に変換可能.
-spec to_float(binary()) -> float().
to_float(Bin) ->
    try
        binary_to_integer(Bin) * 1.0
    catch
        _:_ ->
            binary_to_float(Bin)
    end.

%% @doc 数値表現のバイナリを、整数もしくは浮動小数点数に変換する．
%%
%% 引数で与えられたバイナリが整数表現だった場合は整数に、小数表現だった場合は浮動小数点数に変換する.
%% 整数表現、小数表現のいずれでもなかった場合は badarg を投げる．
-spec to_number(binary()) -> number().
to_number(Bin) ->
    try
        binary_to_integer(Bin)
    catch
        _:_ ->
            binary_to_float(Bin)
    end.

%% @doc バイナリの両端からスペース(\s)を取り除く(strip(Binary, both)).
-spec strip(Binary::binary()) -> binary().
strip(Binary) ->
    strip(Binary, both).

%% @doc 指定された方向のスペースを取り除く(strip(Binary, Direction, &lt;&lt;"\s"&gt;&gt;)).
-spec strip(Binary, Direction) -> Stripped when
      Binary :: binary(),
      Direction :: left | right | both,
      Stripped :: binary().
strip(Binary, Direction) ->
    strip(Binary, Direction, <<"\s">>). % \s: スペース

%% @doc 指定された方向から任意の1文字を全て取り除く(strip(Binary, Direction, Target, single)).
-spec strip(Binary, Direction, Target) -> Stripped when
      Binary :: binary(),
      Direction :: left | right | both,
      Target :: binary(),
      Stripped :: binary().
strip(Binary, Direction, Target) ->
    strip(Binary, Direction, Target, single).

%% @doc 指定された方向から任意の文字を取り除く.
%%
%% 第4引数では次の値を指定.
%% <ul>
%%   <li>single</li>
%%     Targetで指定できる文字は1文字.
%%   <li>order</li>
%%     Targetで複数文字を指定できる. 指定順序通りの場合のみ取り除く.<br />
%%     ex:
%% ```
%% > strip(<<"ababbabcabcabbab">>, both, <<"ab">>, order).
%% <<"babcabcabb">>
%% '''
%%   <li>random</li>
%%     Targetで複数文字を指定できる. 順不同で, 文字それぞれを取り除く.<br />
%%     ex:
%% ```
%% > strip(<<"ababbabcabcabbab">>, both, <<"ab">>, random).
%% <<"cabc">>
%% '''
%% </ul>
-spec strip(Binary, Direction, Target, Type) -> Stripped when
      Binary :: binary(),
      Direction :: left | right | both,
      Target :: binary(),
      Type :: single | order | random,
      Stripped :: binary().
strip(Binary, Direction, Target, Type) when is_binary(Binary) -> % 必要がないがbinary check
    Target2 = case Type of
                  order  -> <<"(", Target/binary, ")">>;
                  random -> <<"[", Target/binary, "]">>;
                  single when size(Target) =:= 1 -> Target
              end,
    case Direction of
        both ->
            re:replace(Binary,
                       <<"^", Target2/binary, "+|", Target2/binary, "+$">>,
                       <<>>, [global, {return, binary}]
                      );
        left  -> re:replace(Binary, <<"^", Target2/binary, "+">>, <<>>, [{return, binary}]);
        right -> re:replace(Binary, <<Target2/binary, "+$">>, <<>>, [{return, binary}])
    end.

%% @equiv abbreviate(Bin, MaxLength, <<"...">>)
-spec abbreviate(binary(), non_neg_integer()) -> binary().
abbreviate(Bin, MaxLength) ->
    abbreviate(Bin, MaxLength, <<"...">>).

%% @doc 入力バイナリが最大長を超えている場合に、指定された省略文字列を使って切り詰めを行う
%%
%% 省略文字列が最大長よりも長い場合は、省略時には省略文字列の長さが優先される。(最大長の指定によって、省略文字列自体が切り詰められることはない)
%%
%% 入力バイナリが、UTF-8でエンコードされた日本語等のマルチバイト文字列の場合、省略の際に文字の境界は考慮されないので、
%% 省略によって不正な文字列が生成される可能性があるので注意が必要。
%%
%% ```
%% %% 省略される場合
%% > abbreviate(<<"hello world">>, 6, <<"...">>).
%% <<"hel...">>
%%　
%% %% 最大長よりも短い場合は、入力バイナリがそのまま返る
%% > abbreviate(<<"hello world">>, 100, <<"...">>).
%% <<"hello world">>
%% '''
-spec abbreviate(Input::binary(), MaxLength::non_neg_integer(), Ellipsis::binary()) -> binary().
abbreviate(<<Bin/binary>>, MaxLength, <<Ellipsis/binary>>) when is_integer(MaxLength), MaxLength >= 0 ->
    case byte_size(Bin) =< MaxLength of
        true  -> Bin;
        false ->
            EllipsisSize = byte_size(Ellipsis),
            TruncateSize = max(0, MaxLength - EllipsisSize),
            <<(binary:part(Bin, 0, TruncateSize))/binary, Ellipsis/binary>>
    end.

%% @doc 入力バイナリ内の文字を、マッピング指定に従って置換する.
%%
%% ```
%% > tr(<<"abcdef">>, [{$a, $1}, {$c, $3}]).
%% <<"1b3def">>
%% '''
-spec tr(binary(), ConvertMapping) -> binary() when
      ConvertMapping :: [{From::char(), To::char()}].
tr(Subject, ConvertMapping) ->
    tr(Subject, 0, byte_size(Subject), ConvertMapping, []).

%% @doc 同じ数字(文字)が連続したバイナリを作る.
%%
%% ```
%% > fill(0, 10).
%% <<0,0,0,0,0,0,0,0,0,0>>
%% > fill($a, 10).
%% <<"aaaaaaaaaa">>
%% '''
-spec fill(Int::integer(), Count::integer()) -> binary().
fill(Int, Count) ->
    Seq = lists:seq(1, Count),
    lists:foldl(fun (_, Bin) -> <<Int/integer, Bin/binary>> end, <<>>, Seq).

%% @doc バイナリリストの要素をセパレータで区切ったバイナリを返す.
-spec join([binary()], Separator::binary()) -> binary().
join([Head1|[Head2|Tail]], Separator) ->
    join([<<Head1/binary, Separator/binary, Head2/binary>>|Tail], Separator);
join([Head], _) -> Head;
join([], _) -> <<>>.

%%----------------------------------------------------------------------------------------------------------------------
%% Internal Functions
%%----------------------------------------------------------------------------------------------------------------------
-spec generate_random_list(ByteSize::non_neg_integer(), Count::non_neg_integer(), Acc::[binary()]) -> [binary()].
generate_random_list(_, 0, Acc) ->
    Acc;
generate_random_list(ByteSize, Count, Acc) ->
    Bin = crypto:rand_bytes(ByteSize),

    %% NOTE: Countのサイズが大きい場合は、かなり非効率になるユニーク確認処理
    case lists:member(Bin, Acc) of
        false -> generate_random_list(ByteSize, Count - 1, [Bin | Acc]);
        true  -> generate_random_list(ByteSize, Count, Acc)
    end.

-spec tr(binary(), non_neg_integer(), non_neg_integer(), [{char(), char()}], iolist()) -> binary().
tr(Bin, Pos, Pos, _Map, Acc) ->
    list_to_binary(lists:reverse([Bin | Acc]));
tr(Bin, Pos, End, Map, Acc) ->
    case lists:keyfind(binary:at(Bin, Pos), 1, Map) of
        false  -> tr(Bin, Pos + 1, End, Map, Acc);
        {_, C} -> <<Before:Pos/binary, _, After/binary>> = Bin,
                  tr(After, 0, byte_size(After), Map, [C, Before | Acc])
    end.

%% @doc 固定小数点表記のバイナリから`number()'を生成する.
%%
%% 固定小数点のバイナリはビッグエンディアン.
%% ```
%% 1> fixed_point_binary_to_number(16, 16, <<0, 1, 128, 0>>).
%% 1.5
%% '''
-spec fixed_point_binary_to_number(IntegerPartLength, DecimalPartLength, binary()) -> number() when
      IntegerPartLength :: integer(),
      DecimalPartLength :: integer().
fixed_point_binary_to_number(IntegerPartLength, DecimalPartLength, Bin) ->
    <<IntegerPart:IntegerPartLength, DecimalPart:DecimalPartLength>> = Bin,
    IntegerPart + DecimalPart / (1 bsl DecimalPartLength).

%% @doc `number()'から固定小数点表記のバイナリを生成する.
%%
%% 固定小数点のバイナリはビッグエンディアン.
%% ```
%% 1> number_to_fixed_point_binary(16, 16, 1.5).
%% <<0, 1, 128, 0>>
%% '''
-spec number_to_fixed_point_binary(IntegerPartLength, DecimalPartLength, number()) -> binary() when
      IntegerPartLength :: integer(),
      DecimalPartLength :: integer().
number_to_fixed_point_binary(IntegerPartLength, DecimalPartLength, Num) ->
    <<(trunc(Num * (1 bsl DecimalPartLength))):(IntegerPartLength + DecimalPartLength)>>.