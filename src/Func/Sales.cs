using Newtonsoft.Json;

namespace Func
{
    public class Sales
    {
        [JsonProperty(PropertyName = "id", DefaultValueHandling = DefaultValueHandling.IgnoreAndPopulate)]
        public string ID { get; set; }

        [JsonProperty(PropertyName = "name", DefaultValueHandling = DefaultValueHandling.IgnoreAndPopulate)]
        public string Name { get; set; }

        [JsonProperty(PropertyName = "price", DefaultValueHandling = DefaultValueHandling.IgnoreAndPopulate)]
        public double Price { get; set; }
    }
}
