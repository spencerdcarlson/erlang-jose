%% -*- mode: erlang; tab-width: 4; indent-tabs-mode: 1; st-rulers: [70] -*-
%% vim: ts=4 sw=4 ft=erlang noet
%%%-------------------------------------------------------------------
%%% @author Andrew Bennett <andrew@pixid.com>
%%% @copyright 2014-2015, Andrew Bennett
%%% @doc
%%%
%%% @end
%%% Created :  21 Jul 2015 by Andrew Bennett <andrew@pixid.com>
%%%-------------------------------------------------------------------
-module(jose_jwk_kty_oct).
-behaviour(jose_jwk).
-behaviour(jose_jwk_kty).
-behaviour(jose_jwk_oct).
-behaviour(jose_jwk_use_enc).
-behaviour(jose_jwk_use_sig).

%% jose_jwk callbacks
-export([from_map/1]).
-export([to_key/1]).
-export([to_map/2]).
-export([to_public_map/2]).
-export([to_thumbprint_map/2]).
%% jose_jwk_kty callbacks
-export([generate_key/1]).
-export([generate_key/2]).
-export([key_encryptor/3]).
%% jose_jwk_use_enc callbacks
-export([block_encryptor/2]).
-export([derive_key/1]).
%% jose_jwk_use_sig callbacks
-export([sign/3]).
-export([signer/2]).
-export([verifier/2]).
-export([verify/4]).
%% jose_jwk_oct callbacks
-export([from_oct/1]).
-export([to_oct/1]).

%% Types
-type key() :: binary().

-export_type([key/0]).

%%====================================================================
%% jose_jwk callbacks
%%====================================================================

from_map(F = #{ <<"kty">> := <<"oct">>, <<"k">> := K }) ->
	{base64url:decode(K), maps:without([<<"k">>, <<"kty">>], F)}.

to_key(Key) ->
	Key.

to_map(K, F) ->
	F#{ <<"kty">> => <<"oct">>, <<"k">> => base64url:encode(K) }.

to_public_map(K, F) ->
	to_map(K, F).

to_thumbprint_map(K, F) ->
	maps:with([<<"k">>, <<"kty">>], to_public_map(K, F)).

%%====================================================================
%% jose_jwk_kty callbacks
%%====================================================================

generate_key(Size) when is_integer(Size) ->
	{crypto:strong_rand_bytes(Size), #{}};
generate_key({oct, Size}) when is_integer(Size) ->
	generate_key(Size).

generate_key(KTY, Fields) ->
	{NewKTY, OtherFields} = generate_key(byte_size(KTY)),
	{NewKTY, maps:merge(maps:remove(<<"kid">>, Fields), OtherFields)}.

key_encryptor(KTY, Fields, Key) ->
	jose_jwk_kty:key_encryptor(KTY, Fields, Key).

%%====================================================================
%% jose_jwk_use_enc callbacks
%%====================================================================

block_encryptor(_KTY, #{ <<"alg">> := ALG, <<"enc">> := ENC, <<"use">> := <<"enc">> }) ->
	#{
		<<"alg">> => ALG,
		<<"enc">> => ENC
	};
block_encryptor(KTY, Fields) ->
	ENC = case bit_size(KTY) of
		128 ->
			<<"A128GCM">>;
		192 ->
			<<"A192GCM">>;
		256 ->
			case jose_jwa:is_block_cipher_supported({aes_gcm, 256}) of
				false ->
					<<"A128CBC-HS256">>;
				true ->
					<<"A256GCM">>
			end;
		384 ->
			<<"A192CBC-HS384">>;
		512 ->
			<<"A256CBC-HS512">>;
		_ ->
			erlang:error({badarg, [KTY, Fields]})
	end,
	#{
		<<"alg">> => <<"dir">>,
		<<"enc">> => ENC
	}.

derive_key(Key) ->
	Key.

%%====================================================================
%% jose_jwk_use_sig callbacks
%%====================================================================

sign(Message, DigestType, Key) ->
	crypto:hmac(DigestType, Key, Message).

signer(_KTY, #{ <<"alg">> := ALG, <<"use">> := <<"sig">> }) ->
	#{
		<<"alg">> => ALG
	};
signer(Key, _Fields) ->
	#{
		<<"alg">> => case bit_size(Key) of
			KeySize when KeySize < 384 -> <<"HS256">>;
			KeySize when KeySize < 512 -> <<"HS384">>;
			_ -> <<"HS512">>
		end
	}.

verifier(_KTY, #{ <<"alg">> := ALG, <<"use">> := <<"sig">> }) ->
	[ALG];
verifier(Key, _Fields) ->
	case bit_size(Key) of
		KeySize when KeySize < 384 -> [<<"HS256">>];
		KeySize when KeySize < 512 -> [<<"HS256">>, <<"HS384">>];
		_ -> [<<"HS256">>, <<"HS384">>, <<"HS512">>]
	end.

verify(Message, DigestType, Signature, Key) ->
	jose_jwa:constant_time_compare(Signature, sign(Message, DigestType, Key)).

%%====================================================================
%% jose_jwk_oct callbacks
%%====================================================================

from_oct(OCTBinary) when is_binary(OCTBinary) ->
	{OCTBinary, #{}}.

to_oct(OCTBinary) when is_binary(OCTBinary) ->
	OCTBinary.

%%%-------------------------------------------------------------------
%%% Internal functions
%%%-------------------------------------------------------------------
