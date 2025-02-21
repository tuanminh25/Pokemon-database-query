#! /usr/bin/env python3

"""
Description: List the number of pokemon and the number of locations in each game
"""


import sys
import psycopg2
import helpers


### Constants
USAGE = f"Usage: {sys.argv[0]}"

def main(db):
    if len(sys.argv) != 1:
        print(USAGE)
        return 1

    # TODO: your code here
    cur = db.cursor()
    
    cur.execute("""
    SELECT 
        region, region_game_locations.game,  pokemon_game.pokemon, locations 
    FROM
        region_game_locations
    JOIN
        pokemon_game ON region_game_locations.id = pokemon_game.game 
    ORDER BY
        region, region_game_locations.game;
    """)

    print("Region Game              #Pokemon #Locations")
    for row in cur.fetchall():
        region, game, pokemon, locations = row
        print(f"{region:<6} {game:<17} {pokemon:<8} {locations}")

if __name__ == '__main__':
    exit_code = 0
    db = None
    try:
        db = psycopg2.connect(dbname="pkmon")
        exit_code = main(db)
    except psycopg2.Error as err:
        print("DB error: ", err)
        exit_code = 1
    except Exception as err:
        print("Internal Error: ", err)
        raise err
    finally:
        if db is not None:
            db.close()
    sys.exit(exit_code)
