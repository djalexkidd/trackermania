# This script converts Quaver beatmaps to TrackerMania beatmaps
# Usage: python qua2tm.py quaver_chart.qua
import yaml
import json
import sys

def convert_quaver_to_note_array(hit_objects):
    # Initialize note arrays for 8 lanes
    note_array = [[] for _ in range(8)]

    for hit_object in hit_objects:
        start_time = hit_object.get('StartTime', 0) / 1000.0 + 2.0  # Convert time into your desired scale
        lane = hit_object.get('Lane', 0) - 1  # Convert 1-based index to 0-based

        # Check for long notes by looking for EndTime
        if 'EndTime' in hit_object:
            end_time = hit_object.get('EndTime', 0) / 1000.0 + 2.0
            length = round(end_time - start_time, 1)  # Calculate length (EndTime - StartTime)
            note = [round(start_time, 1), length]  # Long note [start, length]
        else:
            note = [round(start_time, 1)]  # Regular note with only start time

        # Append the note's start time to the corresponding lane's array
        if 0 <= lane < 8:
            note_array[lane].append(note)  # Round time to 1 decimal place

    return note_array

def convert_quaver_to_json(input_file, output_file):
    # Read the quaver file
    with open(input_file, 'r') as file:
        data = yaml.safe_load(file)

    # Convert HitObjects to noteArray format
    hit_objects = data.get('HitObjects', [])
    note_array = convert_quaver_to_note_array(hit_objects)

    # Add noteArray to the JSON structure
    data['noteArray'] = note_array

    # Remove the HitObjects field, as it's now converted into noteArray
    if 'HitObjects' in data:
        del data['HitObjects']

    # Write everything to a JSON file
    with open(output_file, 'w') as json_file:
        json.dump(data, json_file, indent=4)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    else:
        print("Usage: python qua2tm.py quaver_chart.qua")
        sys.exit()
    output_file = input_file.rsplit(".",1)[0]+'.json'

    convert_quaver_to_json(input_file, output_file)
    print(f"Conversion to JSON completed: {output_file}")
