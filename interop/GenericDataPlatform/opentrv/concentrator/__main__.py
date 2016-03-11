import opentrv.concentrator

if __name__ == "__main__":
    print("Hello concentrator!")
    parser = opentrv.concentrator.OptionParser()
    options = parser.parse()
    core = opentrv.concentrator.Core(options)
    core.run()
