#coding:utf-8

module Qliphort
  module Scout
    module Language
      module_function

      def xiaolong
        Proc.new do
          token SLASH:    /^\/$/
          token RSLSH:    /^\\$/
          token STAR:     /^\*$/
          token PERD:     /^\.$/
          token COMMA:    /^,$/
          token SMCLN:    /^;$/
          token DQUOT:    /^"$/
          token SQUOT:    /^'$/
          token OCRLY:    /^\{$/
          token CCRLY:    /^\}$/
          token OPARN:    /^\($/
          token CPARN:    /^\)$/
          token OBRKT:    /^\[$/
          token CBRKT:    /^\]$/
          token OABKT:    /^\<$/
          token CABKT:    /^\>$/
          token AT:       /^@$/
          token EQUAL:    /^=$/
          token POW:      /^\^$/
          token DOLLR:    /^\$$/
          token PLUS:     /^\+$/
          token EXCLM:    /^!$/
          token QUEST:    /^\?$/

          token SUBMOD:   /^submodule$/
          token BLNGTO:   /^belongs-to$/
          token PREFIX:   /^prefix$/
          token IMPORT:   /^import$/
          token INCLUD:   /^include$/
          token REFER:    /^reference$/
          token GROUP:    /^grouping$/
          token CONTNR:   /^container$/
          token LIST:     /^list$/
          token LEAF:     /^leaf$/
          token RPC:      /^rpc$/
          token INPUT:    /^input$/

          token KEY:      /^key$/
          token CONFIG:   /^config$/
          token MNDTOR:   /^mandatory$/
          token LENGTH:   /^length$/
          token TYPE:     /^type$/
          token PATTRN:   /^pattern$/

          token ORGNIZ:   /^organization$/
          token CONTCT:   /^contact$/
          token DESC:     /^description$/
          token REVSN:    /^revision$/

          token RANGE:    /^range$/
          token DEFAULT:  /^default$/
          token UNITS:    /^units$/
          token BOOL:     /^boolean$/
          token MUST:     /^must$/
          token UINT16:   /^uint16$/
          token UINT32:   /^uint32$/

          token TRUE:     /^true$/
          token FALSE:    /^false$/
          token NAME:     /^[a-z|A-Z|\-|\_|\:]+$/
          token DATE:     /^\d\d\d\d-[0-1]\d-[0-3]\d$/

          token WORD:     /^[\w|\u4e00-\u9fa5]+$/
          token SPWORD:   /^[。]+$/
        end
      end

    end
  end
end
