# $bad: теги outbound'ов без ключа. Транзитивно добавляем тех, кто ходит через них по detour.
. as $cfg
| def closure: . as $b
    | ([$cfg.outbounds[] | select((.detour // null) as $d | $d != null and ($b | index([$d])))
        | .tag] - $b) as $new
    | if ($new | length) == 0 then $b else ($b + $new | closure) end;
  ($bad | closure) as $all
| def dead: . as $t | $t != null and ($all | index([$t]) != null);
  .outbounds |= (map(select(.tag | dead | not))
    | map(if .outbounds then
            .outbounds |= map(select(dead | not))
            | if (.default | dead) then .default = .outbounds[0] else . end
          else . end))
| if .route.rules then .route.rules |= map(select(.outbound | dead | not)) else . end
| if (.route.final | dead) then del(.route.final) else . end
