
from Weights import TidalWeights

def main():
    takeoff_weight = input("Enter the takeoff weight (lbf): ") 
    # This is an error check
    if not isinstance(takeoff_weight, float):
        print("Invalid input. Please enter a numeric value.")
        return
    # Create an instance of TidalWeights
    weights = TidalWeights()
    OEW = weights.OEW(float(takeoff_weight))  # Example takeoff weight of 10,000 lbf


    # Print the initialized values
    print(f"The OEW is: {OEW} lbf")

# ALWAYS INCLUDE THIS LINE OR ELSE IT WILL NOT RUN
if __name__ == "__main__":
    main()
