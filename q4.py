#! /usr/bin/env python3


"""
Description: Print the best move a given pokemon can use against a given type in a given game for each level from 1 to 100
"""


import sys
import psycopg2
import helpers


### Constants
USAGE = f"Usage: {sys.argv[0]} <Game> <Attacking Pokemon> <Defending Pokemon>"


def main(db):
    ### Command-line args
    if len(sys.argv) != 4:
        print(USAGE)
        return 1
    game_name = sys.argv[1]
    attacking_pokemon_name = sys.argv[2]
    defending_pokemon_name = sys.argv[3]
    cur = db.cursor()

    # TODO: your code here
    check_query = "SELECT * FROM Q4_Check('{}', '{}', '{}')".format(game_name, attacking_pokemon_name, defending_pokemon_name)
    cur.execute(check_query)
    output_tuple = cur.fetchall()
    
    if (output_tuple[0][0] != 'TRUE'):
        print(output_tuple[0][0])
    else:
        query = "SELECT * FROM Q4('{}', '{}', '{}')".format(game_name, attacking_pokemon_name, defending_pokemon_name)
        cur.execute(query)
        rows = cur.fetchall()
        if not rows:
            print(f"No moves found for \"{attacking_pokemon_name}\" against \"{defending_pokemon_name}\" in \"{game_name}\"")
        else:
            print(f"If \"{attacking_pokemon_name}\" attacks \"{defending_pokemon_name}\" in \"{game_name}\" it's available moves are:")
            for row in rows:
                move_name, requirements, relative_power = row
                print(f"\t{move_name}\n\t\twould have a relative power of {relative_power}\n\t\tand can be learnt from {requirements}")
        
    
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
