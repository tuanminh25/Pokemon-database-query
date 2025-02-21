#! /usr/bin/env python3


"""
Description: List all locations where a specific pokemon can be found
"""


import sys
import psycopg2
import helpers


### Constants
USAGE = f"Usage: {sys.argv[0]} <pokemon_name>"

def print_table(header, data):
    # Calculate column widths based on the maximum length of each column
    column_widths = [max(len(str(row[i])) for row in data) for i in range(len(header))]
    

    maxGameLen = len(header[0])
    maxLocationLen = len(header[1])
    maxRarityLen = len(header[2])
    maxMinLevelLen = len(header[3])
    maxMaxLevelLen = len(header[4])
    maxRequirementLen = len(header[5])
    
    if (column_widths[0] < maxGameLen): 
        column_widths[0] = maxGameLen
    if (column_widths[1] < maxLocationLen):
        column_widths[1] = maxLocationLen
    if (column_widths[2] < maxRarityLen):
        column_widths[2] = maxRarityLen
    if (column_widths[3] < maxMinLevelLen):
        column_widths[3] = maxMinLevelLen        
    if (column_widths[4] < maxMaxLevelLen):
        column_widths[4] = maxMaxLevelLen
    if (column_widths[5] < maxRequirementLen):
        column_widths[5] = maxRequirementLen
    
    # Print header
    print(" ".join(f"{header[i]:<{column_widths[i]}}" for i in range(len(header))))
    
    # Print data rows
    for row in data:
        print(" ".join(f"{row[i]:<{column_widths[i]}}" for i in range(len(header))))
        
def main(db):
    if len(sys.argv) != 2:
        print(USAGE)
        return 1
    # TODO: your code here
    pokemon_name = sys.argv[1]
    cur = db.cursor()
    
    if (pokemon_name is not None): 
        query = "SELECT * FROM Q2('{}')".format(pokemon_name)
        cur.execute(query)
    
        rows = cur.fetchall()
        game, location, rarity, min_level, max_level, requirements, region = rows[0]
        if (game is None):
            print(requirements)
        else:
            header = ["Game", "Location", "Rarity", "MinLevel", "MaxLevel", "Requirements"]
            # print(rows)
            print_table(header, rows)
           
            # for row in rows:
            #     game, location, rarity, min_level, max_level, requirements = row
            #     print(game, location, rarity, min_level, max_level, requirements)
    else: 
        print("Mising arg")
    
  

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
