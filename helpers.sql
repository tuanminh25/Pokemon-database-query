-- COMP3311 24T1 Ass2 ... SQL helper Views/Functions
-- Add any views or functions you need into this file
-- Note: it must load without error into a freshly created Pokemon database

-- The `dbpop()` function is provided for you in the dump file
-- This is provided in case you accidentally delete it

DROP TYPE IF EXISTS Population_Record CASCADE;
CREATE TYPE Population_Record AS (
	Tablename Text,
	Ntuples   Integer
);

CREATE OR REPLACE FUNCTION DBpop()
    RETURNS SETOF Population_Record
    AS $$
        DECLARE
            rec Record;
            qry Text;
            res Population_Record;
            num Integer;
        BEGIN
            FOR rec IN SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename LOOP
                qry := 'SELECT count(*) FROM ' || quote_ident(rec.tablename);

                EXECUTE qry INTO num;

                res.tablename := rec.tablename;
                res.ntuples   := num;

                RETURN NEXT res;
            END LOOP;
        END;
    $$ LANGUAGE plpgsql
;

--
-- Example Views/Functions
-- These Views/Functions may or may not be useful to you.
-- You may modify or delete them as you see fit.
--

-- `Move_Learning_Info`
-- The `Learnable_Moves` table is a relation between Pokemon, Moves, Games and Requirements.
-- As it just consists of foreign keys, it is not very easy to read.
-- This view makes it easier to read by displaying the names of the Pokemon, Moves and Games instead of their IDs.
CREATE OR REPLACE VIEW Move_Learning_Info(Pokemon, Move, Game, Requirement) AS
    SELECT
        P.Name,
        M.Name,
        G.Name,
        R.Assertion
    FROM
        Learnable_Moves AS L
        JOIN Pokemon AS P
        ON Learnt_By = P.ID
        JOIN Games AS G
        ON Learnt_In = G.ID
        JOIN Moves AS M
        ON Learns = M.ID
        JOIN Requirements AS R
        ON Learnt_When = R.ID
;

-- `Super_Effective`
-- This function takes a type name and
-- returns a set of all types that it is super effective against (multiplier > 100)
-- eg Water is super effective against Fire, so `Super_Effective('Water')` will return `Fire` (amongst others)
CREATE OR REPLACE FUNCTION Super_Effective(_Type Text)
    RETURNS SETOF Text
    AS $$
        SELECT
            B.Name
        FROM
            Types AS A
            JOIN Type_Effectiveness AS E
            ON A.ID = E.Attacking
            JOIN Types AS B
            ON B.ID = E.Defending
        WHERE
            A.Name = _Type
            AND
            E.Multiplier > 100
    $$ LANGUAGE SQL
;

--
-- Your Views/Functions Below Here
-- Remember This file must load into a clean Pokemon database in one pass without any error
-- NOTICEs are fine, but ERRORs are not
-- Views/Functions must be defined in the correct order (dependencies first)
-- eg if my_supper_clever_function() depends on my_other_function() then my_other_function() must be defined first
-- Your Views/Functions Below Here
--

-- Q1 helper
-- Region and Gamge together
CREATE OR REPLACE VIEW region_game AS
SELECT
    games.id,
    games.region,
    games.name,
    locations.appears_in
FROM
    games
JOIN
    locations ON games.id = locations.appears_in;

-- Region game and num locations
CREATE OR REPLACE VIEW region_game_locations AS
SELECT
    id,
    region,
    name AS game,
    COUNT(*) AS locations
FROM
    region_game
GROUP BY
    region,
    name,
    id
ORDER BY
    region;

-- Game and number of pokemon
CREATE OR REPLACE VIEW pokemon_game AS
SELECT
    game,
    COUNT(*) AS pokemon
FROM
    pokedex
GROUP BY
    game;

-- Final view
CREATE OR REPLACE VIEW Q1 AS
SELECT
    region,
    region_game_locations.game,
    pokemon_game.pokemon,
    locations
FROM
    region_game_locations
JOIN
    pokemon_game ON region_game_locations.id = pokemon_game.game
ORDER BY
    region,
    region_game_locations.game;


-- Q2 helper
CREATE OR REPLACE VIEW encounter_detailedRequirements AS
SELECT 
    encounter_requirements.encounter,
    encounter_requirements.requirement,
    encounter_requirements.inverted,
    requirements.assertion
FROM 
    encounter_requirements
JOIN
    requirements ON encounter_requirements.requirement = requirements.id
;

CREATE OR REPLACE VIEW encounter_pokemon_rarity_levels_requirements_all AS
SELECT 
    *
FROM 
    encounter_detailedRequirements
JOIN encounters ON encounters.id = encounter_detailedRequirements.encounter
;


CREATE OR REPLACE VIEW encounterPokemon_rarity_levels_requirements AS
SELECT
    encounter, -- new
    inverted,
    occurs_with,
    occurs_at,
    rarity,
    levels,
    assertion AS Requirements
FROM 
    encounter_pokemon_rarity_levels_requirements_all
;

CREATE OR REPLACE VIEW game_location AS
SELECT 
    games.region,
    games.name AS Game,
    locations.name AS Location,
    locations.id AS location_id,
    games.id AS game_id
FROM
    games
JOIN
    locations ON games.id = locations.appears_in
;

CREATE OR REPLACE VIEW encounterPokemon_game_location_rarity_levels_requirements AS
SELECT
    encounter, -- new
    inverted,
    region,
    occurs_with,
    game,
    location,
    rarity,
    levels,
    requirements
FROM 
    game_location
JOIN 
    encounterPokemon_rarity_levels_requirements ON encounterPokemon_rarity_levels_requirements.occurs_at = game_location.location_id
;

CREATE OR REPLACE VIEW encounterPokemonName_game_location_rarity_levels_requirements AS
SELECT
    encounter, -- new
    inverted,
    region,
    pokemon.name AS Pokemon,
    game,
    location,
    rarity,
    levels,
    requirements
FROM 
    encounterPokemon_game_location_rarity_levels_requirements
JOIN 
    pokemon ON encounterPokemon_game_location_rarity_levels_requirements.occurs_with = pokemon.id
;



CREATE OR REPLACE VIEW q2_encounterPokemon_InvertedRequirements AS
SELECT DISTINCT
    encounter, -- new
    region,
    pokemon,
    game,
    location,
    rarity,
    levels,
    CASE 
        WHEN inverted THEN 'Not ' || requirements 
        ELSE requirements 
    END AS modified_requirements
FROM encounterPokemonName_game_location_rarity_levels_requirements
;


CREATE OR REPLACE VIEW q2_encounterPokemon_CombinedRequirements AS
SELECT DISTINCT
    encounter, -- new
    region,
    pokemon,
    game,
    location,
    rarity,
    levels,
    STRING_AGG(modified_requirements, ', ' ORDER BY modified_requirements) AS combined_requirements
FROM
    q2_encounterPokemon_InvertedRequirements
GROUP BY
    encounter,
    region,
    pokemon,
    game,
    location,
    rarity,
    levels
;

CREATE OR REPLACE VIEW q2_encounterPokemon_RarityCate AS
SELECT DISTINCT
    region,
    pokemon,
    game,
    location,
    rarity,
    CASE    
        WHEN rarity >= 21 THEN 'Common'
        WHEN rarity BETWEEN 6 AND 20 THEN 'Uncommon'
        WHEN rarity BETWEEN 1 AND 5 THEN 'Rare'
        ELSE 'Limited'
    END AS rarity_category,
    levels,
    combined_requirements
FROM q2_encounterPokemon_CombinedRequirements
;


CREATE OR REPLACE VIEW q2_extract_levels AS
SELECT DISTINCT
    region,
    pokemon,
    game,
    location,
    rarity,
    rarity_category,
    (levels).Min AS Min_Level,
    (levels).Max AS Max_Level,
    combined_requirements
FROM q2_encounterPokemon_RarityCate
;

CREATE OR REPLACE FUNCTION Q2_helper(PokemonName TEXT)
    RETURNS TABLE (game TEXT, location TEXT, rarity_category TEXT, Min_Level INTEGER, Max_Level INTEGER, combined_requirements TEXT, region INT)
    AS $$
    BEGIN
        RETURN QUERY
            SELECT DISTINCT
                q2_extract_levels.game,
                q2_extract_levels.location,
                q2_extract_levels.rarity_category,
                q2_extract_levels.Min_Level,
                q2_extract_levels.Max_Level,
                q2_extract_levels.combined_requirements,
                CASE q2_extract_levels.region
                    WHEN 'Kanto' THEN 1
                    WHEN 'Johto' THEN 2
                    WHEN 'Hoenn' THEN 3
                    WHEN 'Sinnoh' THEN 4
                    WHEN 'Unova' THEN 5
                    WHEN 'Kalos' THEN 6
                    WHEN 'Alola' THEN 7
                    WHEN 'Galar' THEN 8
                    WHEN 'Hisui' THEN 9
                    WHEN 'Paldea' THEN 10
                    ELSE 999 -- If there are other regions not in the enum, place them at the end
                END AS region_order
            FROM 
                q2_extract_levels
            WHERE 
                pokemon = PokemonName

            ORDER BY
                region_order,
                game,
                location,
                rarity_category,
                Min_Level,
                Max_Level,
                combined_requirements;
    END
    $$ LANGUAGE PLpgSQL
;



CREATE OR REPLACE FUNCTION Q2(PokemonName TEXT)
    RETURNS TABLE (game TEXT, location TEXT, rarity_category TEXT, Min_Level INTEGER, Max_Level INTEGER, combined_requirements TEXT, region INT)
    AS $$
    DECLARE 
        Existed_Pokemon BOOLEAN;
        Encountered_Pokemon BOOLEAN;
    BEGIN
        -- Find pokemon in the whole pool
        SELECT
            1 INTO Existed_Pokemon
        FROM
            Pokemon
        WHERE 
            Name = PokemonName;
        
        -- Find pokemon in the encounter list
        SELECT
            1 INTO Encountered_Pokemon
        FROM
            q2_extract_levels
        WHERE 
            pokemon = PokemonName;
        


        IF Existed_Pokemon THEN
            IF Encountered_Pokemon THEN
                RETURN QUERY
                    SELECT * FROM Q2_helper(PokemonName);
            ELSE    
                RETURN QUERY
                     SELECT 
                            NULL::TEXT AS game,
                            NULL::TEXT AS location,
                            NULL::TEXT AS rarity_category,
                            NULL::INTEGER AS Min_Level,
                            NULL::INTEGER AS Max_Level,
                            CONCAT('Pokemon "', PokemonName, '" is not encounterable in any game') AS combined_requirements,
                            NULL::TEXT AS region;

            END IF;
        
        ELSE 
            RETURN QUERY
                SELECT  
                        NULL::TEXT AS region,
                        NULL::TEXT AS game,
                        NULL::TEXT AS location,
                        NULL::TEXT AS rarity_category,
                        NULL::INTEGER AS Min_Level,
                        NULL::INTEGER AS Max_Level,
                        CONCAT('Pokemon "', PokemonName, '" does not exist') AS combined_requirements,
                        NULL::TEXT AS region;

        END IF;

    END

    $$ LANGUAGE PLpgSQL
;




-- Q4
-- The effective power of a move is calculated as follows:
-- The moves power from the moves table
-- multiplied by 1.5 (and rounded down) if the moves type is the same as either of the attacking pokemon's types
-- multiplied by the effectiveness of the moves type against the defending pokemon's type(s) (rounded down)

-- Your output should first be ordered by the effective power of the move, then by the name of the move.
-- If A move can be learned by a pokemon in multiple ways, then the requirements should be ordered by the ID of the requirement.

-- Match pokemon and types
-- Assume that every pokemon has its first type


-- Cut pokemon id, species here already
    
-- the game doesn't exist

-- the attacking pokemon doesn't exist

-- the defending pokemon doesn't exist

-- the attacking pokemon isn't in the game

-- the defending pokemon isn't in the game

-- no moves that the attacking pokemon can use against the defending pokemon

-- Def 
CREATE OR REPLACE VIEW pokemon_and_game AS
SELECT
    pokemon.name AS pokemon,
    games.name AS game
FROM 
    pokedex
JOIN 
    pokemon ON pokedex.national_id = pokemon.id
JOIN 
    games ON pokedex.game = games.id
;


CREATE OR REPLACE FUNCTION get_def_draft(gameName TEXT, pokemonName TEXT) 
RETURNS TABLE (
    pokemon TEXT,
    pokemon_first_type INT,
    pokemon_second_type INT,
    game TEXT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        pokemon.name AS pokemon,
        pokemon.first_type AS pokemon_first_type,
        pokemon.second_type AS pokemon_second_type,
        games.name AS game
    FROM 
        pokedex
    JOIN 
        pokemon ON pokedex.national_id = pokemon.id
    JOIN 
        games ON pokedex.game = games.id
    WHERE
        games.name = gameName AND pokemon.name = pokemonName;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_atk_draft(gameName TEXT, pokemonName TEXT) 
RETURNS TABLE (
    game TEXT,
    pokemon TEXT,
    pokemon_first_type INT,
    pokemon_second_type INT,
    requirements TEXT,
    move_name TEXT,
    move_type INT,
    move_power INT, -- Ensure this is an integer data type
    relative_power INT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        games.name AS game,
        pokemon.name AS pokemon,
        pokemon.first_type AS pokemon_first_type,
        pokemon.second_type AS pokemon_second_type,
        STRING_AGG(requirements.assertion, ' OR ' ORDER BY requirements.id) AS requirements,
        moves.name AS move_name,
        moves.of_type AS move_type,
        moves.power::INT AS move_power,
        CASE
            WHEN moves.of_type = pokemon.first_type OR moves.of_type = pokemon.second_type THEN FLOOR(moves.power * 1.5)::INT
            ELSE moves.power
        END AS relative_power
    FROM 
        learnable_moves
    JOIN
        pokemon ON learnable_moves.learnt_by = pokemon.id
    JOIN
        games ON games.id = learnable_moves.learnt_in
    JOIN
        requirements ON requirements.id = learnable_moves.learnt_when
    JOIN
        moves ON moves.id = learnable_moves.learns
    WHERE
        moves.power IS NOT NULL AND games.name = gameName AND pokemon.name = pokemonName
    GROUP BY
        games.name,
        pokemon.name,
        pokemon.first_type,
        pokemon.second_type,
        moves.name,
        moves.of_type,
        moves.power;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION get_type_effective_def(gameName TEXT, pokemonName TEXT) 
RETURNS TABLE (
    attacking INT,
    defending INT,
    multiplier PERCENTAGE
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        Type_Effectiveness.attacking,
        Type_Effectiveness.defending,
        type_effectiveness.multiplier
    FROM
        type_effectiveness
    RIGHT OUTER JOIN
        get_def_draft(gameName, pokemonName) AS def ON Type_Effectiveness.defending = def.pokemon_first_type OR Type_Effectiveness.defending = def.pokemon_second_type;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_type_multiplied_multiplier(gameName TEXT, pokemonName TEXT) 
RETURNS TABLE (
    attacking INT,
    multiplied_multiplier INT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        def.attacking,
        CASE
            WHEN def.attacking = def2.attacking AND def.defending != def2.defending THEN (def.multiplier * def2.multiplier / 100 ) :: INT
            ELSE NULL
        END AS  multiplied_multiplier
    FROM
        get_type_effective_def(gameName, pokemonName) AS def
    JOIN
        get_type_effective_def(gameName, pokemonName) AS def2 ON def.attacking = def2.attacking
    ;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_type_multiplied_multiplier_not_null(gameName TEXT, pokemonName TEXT) 
RETURNS TABLE (
    attacking INT,
    multiplied_multiplier INT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        def.attacking,
        def.multiplied_multiplier
    FROM
        get_type_multiplied_multiplier(gameName, pokemonName) AS def
    WHERE 
        def.multiplied_multiplier IS NOT NULL
    ;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_type_effective_def_final(gameName TEXT, pokemonName TEXT) 
RETURNS TABLE (
    attacking INT,
    multiplier INT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        def.attacking,
        CASE
            WHEN def.attacking = final_def.attacking THEN final_def.multiplied_multiplier
            ELSE def.multiplier
        END AS multiplier
    FROM
        get_type_effective_def(gameName, pokemonName) AS def
    LEFT OUTER JOIN
        get_type_multiplied_multiplier_not_null(gameName, pokemonName) AS final_def ON def.attacking = final_def.attacking
    ;
END;
$$ LANGUAGE plpgsql;







CREATE OR REPLACE FUNCTION get_atk_draft_with_type_effective_def(gameName TEXT, atkPkmon TEXT, defPkmon TEXT) 
RETURNS TABLE (
    game TEXT,
    pokemon TEXT,
    pokemon_first_type INT,
    pokemon_second_type INT,
    requirements TEXT,
    move_name TEXT,
    move_type INT,
    move_power INT,
    relative_power INT,
    attacking INT,
    multiplier INT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT DISTINCT
        ad.game,
        ad.pokemon,
        ad.pokemon_first_type,
        ad.pokemon_second_type,
        ad.requirements,
        ad.move_name,
        ad.move_type,
        ad.move_power,
        ad.relative_power,
        te.attacking,
        te.multiplier
    FROM 
        get_atk_draft(gameName, atkPkmon) AS ad
    LEFT OUTER JOIN 
        get_type_effective_def_final(gameName, defPkmon) AS te ON te.attacking = ad.move_type;

END;
$$ LANGUAGE plpgsql;








CREATE OR REPLACE FUNCTION Q4_draft(GameName Text, AtkPkmon TEXT, DefPkmon TEXT)
RETURNS TABLE (
    game TEXT,
    pokemon TEXT,
    pokemon_first_type INT,
    pokemon_second_type INT,
    requirements TEXT,
    move_name TEXT,
    move_type INT,
    move_power INT,
    relative_power INT,
    attacking INT,
    multiplier INT,
    final_power INT
) AS $$
    BEGIN
    RETURN QUERY
        SELECT DISTINCT
            tb.game,
            tb.pokemon,
            tb.pokemon_first_type,
            tb.pokemon_second_type,
            tb.requirements,
            tb.move_name,
            tb.move_type,
            tb.move_power,
            tb.relative_power,
            tb.attacking,
            tb.multiplier,
            CASE 
                WHEN tb.multiplier IS NULL THEN (tb.relative_power * 1) :: INT
                ELSE FLOOR(tb.relative_power * tb.multiplier / 100) :: INT
            END AS final_power
        FROM 
            get_atk_draft_with_type_effective_def(GameName, AtkPkmon, DefPkmon) AS tb;
    END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION Q4(GameName Text, AtkPkmon TEXT, DefPkmon TEXT)
RETURNS TABLE (
    move_name TEXT,
    requirements TEXT,
    final_power INT
) AS $$
    BEGIN
    RETURN QUERY
        SELECT DISTINCT
            tb.move_name,
            tb.requirements,
            tb.final_power
        FROM 
           q4_draft(GameName, AtkPkmon, DefPkmon) AS tb
        ORDER BY
            final_power DESC,
            move_name
        ;
    END;
$$ LANGUAGE plpgsql;







CREATE OR REPLACE FUNCTION Q4_Check(GameName Text, AtkPkmon TEXT, DefPkmon TEXT)
    RETURNS TEXT
    AS $$
    DECLARE
        Found_AtkPkmon BOOLEAN;
        Found_DefPkmon BOOLEAN;
        AtkPkmon_inGame BOOLEAN;
        DefPkmon_inGame BOOLEAN;
        Found_Move BOOLEAN;
        Found_Game BOOLEAN;
    BEGIN 
        -- Set up game check
        SELECT 
            1 INTO Found_Game
        FROM 
            games
        WHERE
            Name = GameName
        ;

        -- Check Atk Pokemon 
        SELECT 
            1 INTO Found_AtkPkmon
        FROM 
            Pokemon
        WHERE
            Name = AtkPkmon
        ;

        -- Check Def Pokemon 
        SELECT 
            1 INTO Found_DefPkmon
        FROM 
            Pokemon
        WHERE
            Name = DefPkmon
        ;

        -- Conditional checks
        -- Game does not exist
        IF Found_Game IS NULL THEN
            RETURN CONCAT('Game "', GameName, '" does not exist');
        END IF;

        -- Atk Pokemon check in whole system
        IF Found_AtkPkmon IS NULL THEN
            RETURN CONCAT('Pokemon "', AtkPkmon, '" does not exist');
        END IF;

        -- Atk Pokemon check in game
        -- TODO: search atk pokemon in game method
        SELECT
            1 INTO AtkPkmon_inGame
        FROM
            pokemon_and_game
        WHERE
            pokemon_and_game.game = GameName AND pokemon_and_game.pokemon = AtkPkmon
        ;

        IF AtkPkmon_inGame IS NULL THEN
            RETURN CONCAT('Pokemon "', AtkPkmon,'" is not in "', GameName,'"');
            -- RETURN 'Pokemon "' || AtkPkmon || '" is not in "' || GameName || '"';

        END IF;

        -- Def Pokemon check in whole system
        IF Found_DefPkmon IS NULL THEN
            RETURN CONCAT('Pokemon "', DefPkmon, '" does not exist');
        END IF;

        -- Def Pokemon check in game
        -- TODO: search def pokemon in game method
        SELECT
            1 INTO DefPkmon_inGame
        FROM
            pokemon_and_game
        WHERE
            pokemon_and_game.game = GameName AND pokemon_and_game.pokemon = DefPkmon
        ;

        IF DefPkmon_inGame IS NULL THEN
            RETURN CONCAT('Pokemon "', DefPkmon,'" is not in "', GameName,'"');
        END IF;

        -- check does not contain move
        RETURN 'TRUE';
    END
    $$ LANGUAGE PLpgSQL
;


-- Q5
CREATE OR REPLACE VIEW pkmonName_evos_all AS
SELECT 
    evolutions.id,
    evolutions.pre_evolution,
    pre_evo_poke.name AS pre_evo_name,
    evolutions.post_evolution,
    post_evo_poke.name AS post_evo_name,
    evo_req.requirement AS requirement_id,
    evo_req.inverted AS inverted,
    CASE
        WHEN evo_req.inverted THEN 'NOT ' || req.assertion 
        ELSE req.assertion 
    END AS requirement
FROM 
    evolutions 
JOIN   
    pokemon AS pre_evo_poke ON evolutions.pre_evolution = pre_evo_poke.id
JOIN   
    pokemon AS post_evo_poke ON evolutions.post_evolution = post_evo_poke.id
JOIN 
    evolution_requirements AS evo_req ON evo_req.evolution = evolutions.id
JOIN
    requirements AS req ON req.id = evo_req.requirement
;



-- -- SHOW POST EVO
-- SELECT DISTINCT
--     id, 
--     pre_evolution,
--     pre_evo_name,
--     post_evolution,
--     post_evo_name,
--     STRING_AGG(requirement, ' AND ' ORDER BY  inverted ASC, requirement_id ASC)
-- FROM
--     pkmonName_evos_all
-- WHERE
--     pkmonName_evos_all.pre_evo_name = 'Quilava'
-- GROUP BY
--     id, 
--     pre_evolution,
--     pre_evo_name,
--     post_evolution,
--     post_evo_name
-- ORDER BY 
--     pkmonName_evos_all.post_evolution ASC
-- ;








-- -- SHOW AND PRE EVO
-- CREATE OR REPLACE VIEW preEvo_AND_req AS
-- SELECT DISTINCT
--     id, 
--     pre_evolution,
--     pre_evo_name,
--     post_evolution,
--     post_evo_name,
--     STRING_AGG(requirement, ' AND ' ORDER BY  inverted ASC, requirement_id ASC)
-- FROM
--     pkmonName_evos_all
-- WHERE
--     pkmonName_evos_all.post_evo_name = 'Quilava'
-- GROUP BY
--     id, 
--     pre_evolution,
--     pre_evo_name,
--     post_evolution,
--     post_evo_name
-- ORDER BY 
--     pkmonName_evos_all.pre_evolution ASC
-- ;

-- select * from preEvo_AND_req('Ursaluna');

-- function
CREATE OR REPLACE FUNCTION preEvo_AND_req(pokemon_name TEXT)
RETURNS TABLE (
    id INT,
    pre_evolution Pokemon_ID,
    pre_evo_name TEXT,
    post_evolution Pokemon_ID,
    post_evo_name TEXT,
    requirements TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        all_data.id,
        all_data.pre_evolution,
        all_data.pre_evo_name,
        all_data.post_evolution,
        all_data.post_evo_name,
        STRING_AGG(all_data.requirement, ' AND ' ORDER BY all_data.inverted ASC, all_data.requirement_id ASC) AS requirements
    FROM
        pkmonName_evos_all AS all_data
    WHERE
        all_data.post_evo_name = pokemon_name
    GROUP BY
        all_data.id,
        all_data.pre_evolution,
        all_data.pre_evo_name,
        all_data.post_evolution,
        all_data.post_evo_name
    ORDER BY
        all_data.pre_evolution ASC;
END;
$$ LANGUAGE plpgsql;



-- -- SHOW OR PRE EVO
-- CREATE OR REPLACE VIEW preEvo_OR_req AS
-- SELECT DISTINCT
--     pre_evolution,
--     pre_evo_name,
--     post_evolution,
--     post_evo_name,
--     STRING_AGG(string_agg, ' OR ')
-- FROM
--     AND_req
-- WHERE
--     AND_req.post_evo_name = 'Quilava'
-- GROUP BY
--     pre_evolution,
--     pre_evo_name,
--     post_evolution,
--     post_evo_name
-- ORDER BY 
--     AND_req.pre_evolution ASC
-- ;

-- Function
CREATE OR REPLACE FUNCTION preEvo_OR_req(pokemon_name TEXT)
RETURNS TABLE (
    pre_evolution Pokemon_ID,
    pre_evo_name TEXT,
    post_evolution Pokemon_ID,
    post_evo_name TEXT,
    requirements TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        AND_data.pre_evolution,
        AND_data.pre_evo_name,
        AND_data.post_evolution,
        AND_data.post_evo_name,
        STRING_AGG(AND_data.requirements, ' OR ') AS requirements
    FROM
        preEvo_AND_req(pokemon_name) AS AND_data
    WHERE
        AND_data.post_evo_name = pokemon_name
    GROUP BY
        AND_data.pre_evolution,
        AND_data.pre_evo_name,
        AND_data.post_evolution,
        AND_data.post_evo_name
    ORDER BY 
        AND_data.pre_evolution ASC;
END;
$$ LANGUAGE plpgsql;



-- function
CREATE OR REPLACE FUNCTION postEvo_AND_req(pokemon_name TEXT)
RETURNS TABLE (
    id INT,
    pre_evolution Pokemon_ID,
    pre_evo_name TEXT,
    post_evolution Pokemon_ID,
    post_evo_name TEXT,
    requirements TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        all_data.id,
        all_data.pre_evolution,
        all_data.pre_evo_name,
        all_data.post_evolution,
        all_data.post_evo_name,
        STRING_AGG(all_data.requirement, ' AND ' ORDER BY all_data.inverted ASC, all_data.requirement_id ASC) AS requirements
    FROM
        pkmonName_evos_all AS all_data
    WHERE
        all_data.pre_evo_name = pokemon_name
    GROUP BY
        all_data.id,
        all_data.pre_evolution,
        all_data.pre_evo_name,
        all_data.post_evolution,
        all_data.post_evo_name
    ORDER BY
        all_data.post_evolution ASC;
END;
$$ LANGUAGE plpgsql;

-- Function
CREATE OR REPLACE FUNCTION postEvo_OR_req(pokemon_name TEXT)
RETURNS TABLE (
    pre_evolution Pokemon_ID,
    pre_evo_name TEXT,
    post_evolution Pokemon_ID,
    post_evo_name TEXT,
    requirements TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        AND_data.pre_evolution,
        AND_data.pre_evo_name,
        AND_data.post_evolution,
        AND_data.post_evo_name,
        STRING_AGG(AND_data.requirements, ' OR ') AS requirements
    FROM
        postEvo_AND_req(pokemon_name) AS AND_data
    WHERE
        AND_data.pre_evo_name = pokemon_name
    GROUP BY
        AND_data.pre_evolution,
        AND_data.pre_evo_name,
        AND_data.post_evolution,
        AND_data.post_evo_name
    ORDER BY 
        AND_data.post_evolution ASC;
END;
$$ LANGUAGE plpgsql;

