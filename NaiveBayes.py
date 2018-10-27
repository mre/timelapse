import numpy as np
from collections import Counter, defaultdict
import operator


def occurrences(list1):
    no_of_examples = len(list1)
    prob = dict(Counter(list1))
    for key in prob.keys():
        prob[key] = prob[key] / float(no_of_examples)
    return prob


def naive_bayes(training, outcome, new_sample):
    classes = np.unique(outcome)
    rows, cols = np.shape(training)
    likelihoods = {}
    for cls in classes:
        likelihoods[cls] = defaultdict(list)

    class_probabilities = occurrences(outcome)

    for cls in classes:
        row_indices = np.where(outcome == cls)[0]
        subset = training[row_indices, :]
        r, c = np.shape(subset)
        for j in range(0, c):
            likelihoods[cls][j] += list(subset[:, j])

    for cls in classes:
        for j in range(0, cols):
            likelihoods[cls][j] = occurrences(likelihoods[cls][j])

    results = {}
    for cls in classes:
        class_probability = class_probabilities[cls]
        for i in range(0, len(new_sample)):
            relative_values = likelihoods[cls][i]
            if new_sample[i] in relative_values.keys():
                class_probability *= relative_values[new_sample[i]]
            else:
                class_probability *= 0
            results[cls] = class_probability

    # Printing Probabilities
    print (results)

    # Getting the maximum probability
    i = max(results.items(), key=operator.itemgetter(1))[0]
    print
    "The new document belings to class: {}".format(i)


if __name__ == "__main__":
    # Term DOCUMENT Frequency Matrix
    training = np.asarray(((1, 1, 1, 1, 0, 0, 0, 0, 0, 0), (1, 0, 1, 1, 1, 0, 0, 0, 0, 0),
                           (0, 0, 0, 2, 0, 1, 1, 1, 0, 0), (0, 0, 0, 0, 0, 0, 0, 0, 1, 1),
                           (0, 0, 0, 1, 0, 1, 1, 1, 0, 1)));

    # Class of Documents
    outcome = np.asarray((0, 1, 0, 1, 0))

    # Document to be classified
    new_sample = np.asarray((1, 0, 0, 0, 1, 0, 0, 0, 1, 1))
    naive_bayes(training, outcome, new_sample)
