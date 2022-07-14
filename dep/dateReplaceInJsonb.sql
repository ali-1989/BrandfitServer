BEGIN;
LOCK TABLE "UserFitnessData" IN EXCLUSIVE MODE;

do $$
    declare today date;
    declare r jsonb; -- RECORD
    declare idx int :=0;

    begin
        INSERT INTO "UserFitnessData" (UserId, Nodes)
        values (1, '{"FrontImage": [{"value":"50","date":"2021-07-28 18:17:33.000"}]}');
    EXCEPTION WHEN unique_violation THEN
        today := '2021-07-25 18:17:33.000'::date;

        FOR r IN
            SELECT jsonb_array_elements(Nodes->'FrontImage') arr FROM "UserFitnessData" WHERE userid = 1
            LOOP
                IF (r->>'date')::date = today THEN

                    UPDATE "UserFitnessData"
                    SET Nodes = Nodes #- FORMAT('{"FrontImage", %s}', idx)::text[] WHERE userid = 1;

                    idx := idx-1;

                    UPDATE "UserFitnessData"
                    SET Nodes = jsonb_set("UserFitnessData".Nodes, '{"FrontImage"}',
                                          "UserFitnessData".Nodes->'FrontImage' || '{"value":"1245","date":"2021-07-27 18:17:43.000"}')
                    WHERE userid = 1;
                END IF;
                idx := idx+1;

        END LOOP;
        RETURN;
    end $$;

COMMIT;

=================================================================================================================
CREATE OR REPLACE PROCEDURE x(in ts varchar, in data varchar, in nodeName varchar, in user_Id bigint, inout res int)
    LANGUAGE plpgsql
AS $$
--DECLARE
    declare today date;
    declare r jsonb; -- RECORD
    declare idx int :=0;
    declare cnt int :=0;

BEGIN
    INSERT INTO "UserFitnessData" (UserId, Nodes)
        values (user_Id, FORMAT('{"%s": [%s]}', nodeName, data)::jsonb);
    EXCEPTION WHEN unique_violation THEN
        today := ts::date;

        FOR r IN
            SELECT jsonb_array_elements(Nodes->$3) arr FROM "UserFitnessData" WHERE userid = user_Id
            LOOP
                IF (r->>'date')::date = today THEN

                    UPDATE "UserFitnessData"
                    SET Nodes = Nodes #- FORMAT('{"%s", %s}', nodeName, idx)::text[] WHERE userid = user_Id;

                    idx := idx-1;
                    cnt := cnt+1;

                    UPDATE "UserFitnessData"
                    SET Nodes = jsonb_set("UserFitnessData".Nodes, ('{"'|| nodeName ||'"}')::text[],
                                          "UserFitnessData".Nodes->$3 || data::jsonb)
                    WHERE userid = user_Id;
                END IF;
                idx := idx+1;
        END LOOP;
		
		IF cnt = 0 THEN
            UPDATE "UserFitnessData"
            SET Nodes = jsonb_set("UserFitnessData".Nodes, ('{"'|| nodeName ||'"}')::text[],
                                  "UserFitnessData".Nodes->$3 || data::jsonb)
            WHERE userid = user_Id;

            cnt := 1;
        END IF;
		
        COMMIT;
    --RETURN;
        SELECT cnt INTO res;
        --res := cnt;
END $$;

drop PROCEDURE x;
call x('2021-07-22 18:17:33.000', '{"value":10, "date":"2021-07-22 18:17:33.000"}', 'Weight', 1, 0);
































old:
var q = '''
    do \$\$
        declare today date;
        declare r jsonb;
        declare idx int := 0;
        declare cnt int := 0;
    
    BEGIN;
      LOCK TABLE "${DbNames.T_UserFitnessData}" IN EXCLUSIVE MODE;
    
        begin
            INSERT INTO "${DbNames.T_UserFitnessData}" (UserId, Nodes)
            values ($userId, '{"$nodeName": [$data]}');
        EXCEPTION WHEN unique_violation THEN
            today := '$ts'::date;
    
            FOR r IN
                SELECT jsonb_array_elements(Nodes->'$nodeName') arr FROM "${DbNames.T_UserFitnessData}" WHERE userid = $userId
                LOOP
                    IF (r->>'date')::date = today THEN
    
                        UPDATE "${DbNames.T_UserFitnessData}"
                        SET Nodes = Nodes #- FORMAT('{"$nodeName", %s}', idx)::text[] WHERE userid = $userId;
    
                        idx := idx-1;
                        cnt := cnt+1;
    
                        UPDATE "${DbNames.T_UserFitnessData}"
                        SET Nodes = jsonb_set("${DbNames.T_UserFitnessData}".Nodes, '{"$nodeName"}',
                                              "${DbNames.T_UserFitnessData}".Nodes->'$nodeName' || '$data')
                                      WHERE userid = $userId;
                    END IF;
                    idx := idx+1;
    
            END LOOP;
            RETURN;
        end \$\$;
    
    COMMIT;
    ''';