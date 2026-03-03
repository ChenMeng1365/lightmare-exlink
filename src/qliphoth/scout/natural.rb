
module Qliphort
  module Scout
    module Language
      module_function

      def natural
        Proc.new do 
          token PERD:  /^\.$/
          token COMMA: /^,$/
          token QUEST: /^\?$/
          token EXCLM: /^!$/
          token COLON: /^:$/
          token SMCLN: /^;$/
          token DQUOT: /^"$/
          token SQUOT: /^'$/
          token DASH:  /^\-$/
          token OPARN: /^\($/
          token CPARN: /^\)$/
          token OBRKT: /^\[$/
          token CBRKT: /^\]$/
          token OCRLY: /^\{$/
          token CCRLY: /^\}$/
          token SLASH: /^\/$/
          token BSLSH: /^\\$/
          token WORD:  /^[\w]+$/
        end
      end
      
    end
  end
end
