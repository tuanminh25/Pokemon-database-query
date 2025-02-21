#! /usr/bin/env python3

"""
Description: Print a formatted (recursive) evolution chain for a given pokemon
"""

import sys
import psycopg2
import helpers


### Constants
USAGE = f"Usage: {sys.argv[0]} <pokemon_name>"

def ORclausesHandler(or_clauses, formatted):
    # Process each OR clauses
    for or_index, or_part in enumerate(or_clauses):
        and_clauses = or_part.split(' AND ')
        and_formatted = []

        # Process each AND-separated section
        for and_part in and_clauses:
            if and_part:
                # Clean up and standardize the text
                and_formatted.append(and_part.strip())

        # Join all AND conditions with proper indentation
        if and_formatted:
            if len(and_formatted) == 1:
                # If there's only one condition, format without 'AND'
                and_block = "\t" + and_formatted[0]
            else:
                and_block ="\t\t" + "\n\tAND\n\t\t".join(and_formatted)
            formatted.append(and_block)


def format_conditions(requirements):
    # Initialize the formatted string
    formatted = []
    or_clauses = requirements.split(' OR ')

    # Process each OR clauses
    ORclausesHandler(or_clauses, formatted)

    # Join the whole block ensuring it starts with an indent due to nested conditions
    if len(formatted) >= 2:
        or_formatted = []
        for item in formatted:
            if 'AND' not in item:
                or_formatted.append("\t" + item)
            else:
                and_formatted = item.split('AND\n')
                and_block ="\t" + "\n\t\tAND\n\t".join(and_formatted)
                or_formatted.append(and_block)
        return "\n\tOR\n".join(or_formatted)
    return "\n\tOR\n".join(formatted)


def main(db):
    if len(sys.argv) != 2:
        print(USAGE)
        return 1

    pokemon_name = sys.argv[1]

    # TODO: your code here
    cur = db.cursor()
    cur.execute(f"SELECT * FROM pokemon WHERE name = '{pokemon_name}'")
    rows = cur.fetchall()
    if not rows:
        print(f"Pokemon \"{pokemon_name}\" does not exist")
    else:
        preEvoMoment(cur, pokemon_name)
        postEvoMoment(cur, pokemon_name)
    
def preEvoMoment(cur, pokemon_name):
    # PreEvoMoment
    preEvoQuery = "SELECT * FROM preEvo_OR_req('{}')".format(pokemon_name)
    cur.execute(preEvoQuery)
    rows = cur.fetchall()
    if not rows:
        print(f"\n'{pokemon_name}' doesn't have any pre-evolutions.\n")
    else:
        for row in rows:
            pre_evo, pre_evo_name, post_evo, post_evo_name, req = row
            print(f"'{post_evo_name}' can evolve from '{pre_evo_name}' when the following requirements are satisfied:")
            # print(row)
            print(format_conditions(req))
            preEvoMoment(cur, pre_evo_name)

def postEvoMoment(cur, pokemon_name):
    # PostEvoMoment
    postEvoQuery = "SELECT * FROM postEvo_OR_req('{}')".format(pokemon_name)
    cur.execute(postEvoQuery)
    rows = cur.fetchall()
    if not rows:
        print(f"\n'{pokemon_name}' doesn't have any post-evolutions.\n")
    else:
        for row in rows:
            pre_evo, pre_evo_name, post_evo, post_evo_name, req = row
            print(f"'{pre_evo_name}' can evolve into '{post_evo_name}' when the following requirements are satisfied:")
            print(format_conditions(req))
            postEvoMoment(cur, post_evo_name)






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
